require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'uri'
require_relative '../helper/github_helper'
require_relative '../helper/revenuecat_internal_helper'
require_relative '../helper/versioning_helper'

module Fastlane
  module Actions
    class CreateHotfixAction < Action
      REQUESTED_VERSION_PATTERN = /\A\d+(\.\d+\.\d+)?\z/
      STABLE_TAG_PATTERN = /\A\d+\.\d+\.\d+(\+[0-9A-Za-z.-]+)?\z/

      # rubocop:disable Metrics/PerceivedComplexity
      def self.run(params)
        repo_name = params[:repo_name]
        pr_number = params[:pr_number]
        update_dependencies = params[:update_dependencies]
        dependency_releases = params[:dependency_releases]
        requested_version = params[:version]
        github_pr_token = params[:github_pr_token]
        changelog_latest_path = params[:changelog_latest_path]

        unless requested_version.match?(REQUESTED_VERSION_PATTERN)
          UI.user_error!("Invalid version '#{requested_version}'. Pass the release to patch, like 10.2.0, or a major, like 10.")
        end

        UI.user_error!("Pass either pr_number or update_dependencies.") unless pr_number.nil? ^ update_dependencies.nil?
        UI.user_error!("Pass the dependency_releases that update_dependencies applies.") if update_dependencies && dependency_releases.empty?

        if pr_number
          pull_request = github_api('GET', repo_name, "/pulls/#{pr_number}", github_pr_token)[:json]
          default_branch = pull_request.dig('base', 'repo', 'default_branch')
          UI.user_error!("PR ##{pr_number} is not merged.") unless pull_request['merged_at']
          unless pull_request.dig('base', 'ref') == default_branch
            UI.user_error!("PR ##{pr_number} was merged into #{pull_request.dig('base', 'ref')}, not #{default_branch}. Hotfixes start from a fix merged into #{default_branch}.")
          end
          fix_sha = pull_request['merge_commit_sha']
          change_marker = "(cherry picked from commit #{fix_sha})"
          change_summary = "PR ##{pr_number} (#{pull_request['title']})"
        else
          dependency_releases.each { |dependency_repo, version| ensure_release_exists(dependency_repo, version, github_pr_token) }
          dependencies = dependency_releases.sort.map { |dependency_repo, version| "#{dependency_repo} #{version}" }.join(', ')
          change_marker = "(hotfix dependency update: #{dependencies})"
          change_summary = "dependency update to #{dependencies}"
        end

        Actions.sh('git', 'fetch', '--force', 'origin', 'refs/tags/*:refs/tags/*', *default_branch)
        tags = Actions.sh('git', 'tag', log: false).split("\n")
        tag = resolve_tag(requested_version, tags)
        next_version = next_patch_version(tag)
        next_core_version = core_version(next_version)
        if tags.any? { |existing_tag| core_version(existing_tag) == next_core_version }
          UI.user_error!("#{next_core_version} is already released. Hotfix #{next_core_version} instead of #{tag}.")
        end
        if pr_number
          UI.user_error!("#{tag} already contains #{fix_sha}, so there is nothing to hotfix.") if git_succeeds?('merge-base', '--is-ancestor', fix_sha, tag)

          author_name = Actions.sh('git', 'log', '-1', '--format=%an', fix_sha, log: false).strip
          changelog = Helper::VersioningHelper.changelog_for_pull_request(pull_request, author_name)
          UI.user_error!("PR ##{pr_number} is excluded from changelogs, so there is nothing to release.") if changelog.empty?
        end

        base_branch = "hotfix/#{tag}"
        release_branch = "release/#{next_version}"
        UI.important("Hotfix of #{change_summary} on #{tag}: release PR #{release_branch} into #{base_branch}")
        UI.message("Changelog:\n#{changelog}") if changelog

        if params[:dry_run]
          UI.important("Dry run: no branches, commits or PRs were created.")
          return nil
        end

        Actions::EnsureGitStatusCleanAction.run(show_diff: true)
        UI.user_error!("Cancelled") if UI.interactive? && !UI.confirm("Create #{release_branch}?")
        starting_branch = Actions.sh('git', 'rev-parse', '--abbrev-ref', 'HEAD', log: false).strip

        tag_commit = Actions.sh('git', 'rev-list', '-n', '1', tag, log: false).strip
        ensure_base_branch(repo_name, base_branch, tag_commit, github_pr_token)
        check_out_release_branch(release_branch, tag)
        UI.user_error!("#{release_branch} is not based on #{tag}. Delete it to start over.") unless git_succeeds?('merge-base', '--is-ancestor', tag, 'HEAD')
        progress = release_branch_progress(tag, change_marker, next_version, release_branch)

        if pr_number
          cherry_pick(fix_sha, release_branch, repo_name, pr_number, tag, github_pr_token) unless progress[:change]
        else
          changelog_entry = if progress[:change]
                              progress[:change].join("\n").delete_suffix(change_marker).strip
                            else
                              apply_dependency_update(update_dependencies, next_version, change_marker)
                            end
          changelog = Helper::VersioningHelper.changelog_for_dependency_update(changelog_entry)
        end

        unless progress[:bumped]
          ensure_version_files_contain(tag, params[:files_to_update])
          ensure_version_files_contain(tag, params[:files_to_update_without_prerelease_modifiers])
          Helper::RevenuecatInternalHelper.replace_version_number(tag,
                                                                  next_version,
                                                                  params[:files_to_update],
                                                                  params[:files_to_update_without_prerelease_modifiers],
                                                                  params[:files_to_update_on_latest_stable_releases])
          Helper::RevenuecatInternalHelper.write_changelog(changelog, changelog_latest_path)
          Helper::RevenuecatInternalHelper.attach_changelog_to_main(next_version, changelog_latest_path, params[:changelog_path])
          Helper::RevenuecatInternalHelper.commit_current_changes("Version bump for #{next_version}")
        end

        Actions.sh('git', 'push', '--set-upstream', 'origin', release_branch)

        release_pr_url = open_pr_url(repo_name, release_branch, base_branch, github_pr_token)
        if release_pr_url.nil?
          body = pr_number ? "Hotfix of ##{pr_number} on #{tag}.\n\n#{changelog}" : "Hotfix on #{tag}.\n\n#{changelog}"
          release_pr_url = Helper::RevenuecatInternalHelper.create_pr("Release/#{next_version}", body, repo_name, base_branch, release_branch, github_pr_token, labels: ['pr:next_release'])
          if pr_number
            github_api('POST', repo_name, "/issues/#{pr_number}/comments", github_pr_token,
                       body: { body: "Hotfix release PR for #{tag}: #{release_pr_url}\n\n#{next_steps(release_pr_url, next_version, base_branch)}" })
          end
        end

        Actions.sh('git', 'checkout', starting_branch) if UI.interactive?
        UI.success("Hotfix release PR: #{release_pr_url}\n#{next_steps(release_pr_url, next_version, base_branch)}")
        release_pr_url
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.resolve_tag(requested_version, tags)
        candidates = tags.grep(STABLE_TAG_PATTERN)
        candidates = if requested_version.include?('.')
                       candidates.select { |tag| core_version(tag) == requested_version }
                     else
                       candidates.select { |tag| tag.split('.').first == requested_version }
                     end
        UI.user_error!("No release tag matches #{requested_version}.") if candidates.empty?

        candidates.max_by { |tag| Gem::Version.new(core_version(tag)) }
      end

      def self.next_patch_version(tag)
        core, metadata = tag.split(DELIMITER_BUILD_METADATA, 2)
        major, minor, patch = core.split('.')
        next_core = "#{major}.#{minor}.#{patch.to_i + 1}"
        metadata ? "#{next_core}#{DELIMITER_BUILD_METADATA}#{metadata}" : next_core
      end

      private_class_method def self.core_version(version)
        version.split(DELIMITER_BUILD_METADATA).first
      end

      private_class_method def self.github_api(http_method, repo_name, subpath, github_pr_token, **options)
        Helper::GitHubHelper.github_api_call_with_retry(server_url: 'https://api.github.com',
                                                        http_method: http_method,
                                                        path: "/repos/RevenueCat/#{repo_name}#{subpath}",
                                                        api_token: github_pr_token,
                                                        **options)
      end

      private_class_method def self.ensure_base_branch(repo_name, base_branch, tag_commit, github_pr_token)
        response = github_api('POST', repo_name, '/git/refs', github_pr_token,
                              body: { ref: "refs/heads/#{base_branch}", sha: tag_commit },
                              error_handlers: { 422 => proc {} })
        response = github_api('GET', repo_name, "/git/ref/heads/#{base_branch}", github_pr_token) if response[:status] == 422
        base_branch_sha = response[:json].dig('object', 'sha')
        unless base_branch_sha == tag_commit
          UI.user_error!("#{base_branch} points at #{base_branch_sha}, not at the tagged commit #{tag_commit}.")
        end
      end

      private_class_method def self.check_out_release_branch(release_branch, tag)
        exists_locally = !Actions.sh('git', 'branch', '--list', release_branch, log: false).strip.empty?
        exists_remotely = !Actions.sh('git', 'ls-remote', '--heads', 'origin', release_branch, log: false).strip.empty?
        if exists_locally
          Actions.sh('git', 'checkout', release_branch)
          Actions.sh('git', 'pull', '--ff-only', 'origin', release_branch) if exists_remotely
        elsif exists_remotely
          Actions.sh('git', 'fetch', 'origin', "#{release_branch}:#{release_branch}")
          Actions.sh('git', 'checkout', release_branch)
        else
          Actions.sh('git', 'checkout', '-b', release_branch, tag)
        end
      end

      private_class_method def self.release_branch_progress(tag, change_marker, next_version, release_branch)
        commits = Actions.sh('git', 'log', '--format=%s%x1f%b%x1e', "#{tag}..HEAD", log: false)
                         .split("\x1e").map(&:strip).reject(&:empty?).map { |commit| commit.split("\x1f", 2) }
        changes, other_commits = commits.partition { |_, body| body.to_s.include?(change_marker) }
        bumps, unexpected_commits = other_commits.partition { |subject, _| subject == "Version bump for #{next_version}" }
        unless unexpected_commits.empty?
          UI.user_error!("#{release_branch} already has commits that are not part of this hotfix: #{unexpected_commits.map(&:first).join(', ')}. Release or close that hotfix first, or delete the branch if it is stale.")
        end
        { change: changes.first, bumped: !bumps.empty? }
      end

      private_class_method def self.ensure_release_exists(dependency_repo, version, github_pr_token)
        response = github_api('GET', dependency_repo, "/releases/tags/#{version}", github_pr_token, error_handlers: { 404 => proc {} })
        UI.user_error!("#{dependency_repo} has no #{version} release.") if response[:status] == 404
      end

      private_class_method def self.next_steps(release_pr_url, next_version, base_branch)
        "Approve #{release_pr_url} but don't merge it: approval tags #{next_version}, then CircleCI deploys it and merges the PR into `#{base_branch}`. " \
          "Then delete `#{base_branch}` and add #{next_version} to `CHANGELOG.md` on main. " \
          "RELEASING.md lists any steps specific to this repo."
      end

      private_class_method def self.apply_dependency_update(update_dependencies, next_version, change_marker)
        changelog_entry = update_dependencies.call(next_version).to_s.strip
        UI.user_error!("update_dependencies must return the changelog entry.") if changelog_entry.empty?
        UI.user_error!("update_dependencies changed no files.") if Actions.sh('git', 'status', '--porcelain', log: false).strip.empty?

        subject, details = changelog_entry.split("\n", 2)
        Actions.sh('git', 'add', '--all')
        Actions.sh('git', 'commit', '-m', [subject, details, change_marker].compact.join("\n\n"))
        changelog_entry
      end

      private_class_method def self.cherry_pick(fix_sha, release_branch, repo_name, pr_number, tag, github_pr_token)
        return if git_succeeds?('cherry-pick', '-x', fix_sha)

        conflicted = !Actions.sh('git', 'diff', '--name-only', '--diff-filter=U', log: false).strip.empty?
        command = "bundle exec fastlane hotfix pr:#{pr_number} version:#{core_version(tag)}"
        if conflicted && UI.interactive?
          UI.user_error!("Cherry-picking #{fix_sha} onto #{release_branch} conflicts. Resolve the conflicts, run `git cherry-pick --continue`, then rerun `#{command}`.")
        end

        Actions.sh('git', 'cherry-pick', '--abort', error_callback: ->(_) {})
        if conflicted
          failure = "conflicts"
          next_step = "Run `#{command}` locally from the default branch, resolve the conflicts, run `git cherry-pick --continue`, then rerun the same command."
        else
          failure = "failed without conflicts, so #{tag} may already contain an equivalent change"
          next_step = "See the CI log."
        end
        unless UI.interactive?
          github_api('POST', repo_name, "/issues/#{pr_number}/comments", github_pr_token,
                     body: { body: "Hotfix on #{tag} failed: cherry-picking #{fix_sha} #{failure}. #{next_step}" })
        end
        UI.user_error!("Cherry-picking #{fix_sha} onto #{release_branch} #{failure}. See the git output above.")
      end

      private_class_method def self.git_succeeds?(*command)
        succeeded = true
        Actions.sh('git', *command, error_callback: ->(_) { succeeded = false })
        succeeded
      end

      private_class_method def self.ensure_version_files_contain(version, files_with_patterns)
        files_with_patterns.each do |path, patterns|
          UI.user_error!("#{path} does not exist on #{version}.") unless File.exist?(path)

          contents = File.read(path)
          unless patterns.any? { |pattern| contents.include?(pattern.gsub('{x}', version)) }
            UI.user_error!("#{path} does not contain version #{version}. Its layout on #{version} may differ from the default branch.")
          end
        end
      end

      private_class_method def self.open_pr_url(repo_name, head_branch, base_branch, github_pr_token)
        query = URI.encode_www_form(head: "RevenueCat:#{head_branch}", base: base_branch, state: 'open')
        github_api('GET', repo_name, "/pulls?#{query}", github_pr_token)[:json].first&.dig('html_url')
      end

      def self.description
        "Creates a hotfix release PR for an older release: cherry-picks a PR merged into the default branch, or applies a dependency update, onto the release's tag, bumps the patch version and opens the release PR."
      end

      def self.authors
        ["Álvaro Brey"]
      end

      def self.return_value
        "The URL of the hotfix release PR, or nil on a dry run"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :pr_number,
                                       description: "Number of the PR, merged into the default branch, whose fix to release. Pass this or update_dependencies",
                                       optional: true,
                                       type: Integer),
          FastlaneCore::ConfigItem.new(key: :update_dependencies,
                                       description: "Lambda that updates the dependency versions on the release branch without committing them. It receives the hotfix version and returns its changelog entry, without the leading `* `. Pass this or pr_number",
                                       optional: true,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :dependency_releases,
                                       description: "Hash of RevenueCat repo names to the versions update_dependencies applies, like { 'purchases-android' => '10.31.0' }. Each must have a GitHub release",
                                       optional: true,
                                       default_value: {},
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Release to patch: a version like 10.2.0, or a major like 10 for its latest release",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :changelog_latest_path,
                                       description: "Path to CHANGELOG.latest.md file",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :changelog_path,
                                       description: "Path to CHANGELOG.md file",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :files_to_update,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_VERSION",
                                       description: 'Hash of files that contain the version number, to the patterns that contain it. Same as in bump_version_update_changelog_create_pr',
                                       optional: false,
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :files_to_update_without_prerelease_modifiers,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_VERSION_WITHOUT_PRERELEASE_MODIFIERS",
                                       description: 'Hash of files that contain the version number without prerelease modifiers. Same as in bump_version_update_changelog_create_pr',
                                       optional: true,
                                       default_value: {},
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :files_to_update_on_latest_stable_releases,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_ON_LATEST_STABLE_RELEASES",
                                       description: 'Hash of files only updated when releasing the latest stable version. Same as in bump_version_update_changelog_create_pr',
                                       optional: true,
                                       default_value: {},
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       env_name: "RC_INTERNAL_REPO_NAME",
                                       description: "Name of the repo of the SDK",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_pr_token,
                                       env_name: "GITHUB_PULL_REQUEST_API_TOKEN",
                                       description: "Github token to create the base branch, the release PR and the comments",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :dry_run,
                                       description: "Print the hotfix that would be created without changing anything",
                                       optional: true,
                                       is_string: false,
                                       default_value: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
