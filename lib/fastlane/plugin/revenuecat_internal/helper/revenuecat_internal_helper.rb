require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require 'fastlane/actions/push_to_git_remote'
require 'fastlane/actions/create_pull_request'
require 'fastlane/actions/ensure_git_branch'
require 'fastlane/actions/ensure_git_status_clean'
require 'fastlane/actions/set_github_release'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)
  SUPPORTED_PR_LABELS = %w[breaking build ci docs feat fix perf refactor style test].to_set

  module Helper
    class RevenuecatInternalHelper
      @@cached_commits_by_old_version = {}
      @@prs_by_sha = {}

      def self.replace_version_number(previous_version_number, new_version_number, files_to_update, files_to_update_without_prerelease_modifiers)
        previous_version_number_without_prerelease_modifiers = previous_version_number.split("-")[0]
        new_version_number_without_prerelease_modifiers = new_version_number.split("-")[0]

        files_to_update.each do |file_to_update|
          replace_in(previous_version_number, new_version_number, file_to_update)
        end
        files_to_update_without_prerelease_modifiers.each do |file_to_update|
          replace_in(previous_version_number_without_prerelease_modifiers, new_version_number_without_prerelease_modifiers, file_to_update)
        end
      end

      def self.auto_generate_changelog(repo_name, github_token, rate_limit_sleep)
        old_version = Actions.sh("git describe --tags --abbrev=0").strip
        UI.important("Auto-generating changelog since #{old_version}")

        org = "RevenueCat"

        path = "/repos/#{org}/#{repo_name}/compare/#{old_version}...HEAD"

        # Get all commits from previous version (tag) to HEAD
        resp = Actions::GithubApiAction.run(server_url: 'https://api.github.com',
                                            path: path,
                                            http_method: 'GET',
                                            body: {},
                                            api_token: github_token)
        body = JSON.parse(resp[:body])
        commits = body["commits"].reverse

        @@cached_commits_by_old_version[old_version] ||= commits

        changelog_sections = { breaking_changes: [], fixes: [], new_features: [], other: [] }

        commits.map do |commit|
          if rate_limit_sleep > 0
            UI.message("Sleeping #{rate_limit_sleep} second(s) to avoid rate limit 🐌")
            sleep(rate_limit_sleep)
          end

          name = commit["commit"]["author"]["name"]

          # Get pull request associate with commit message
          sha = commit["sha"]
          pr_resp = Actions::GithubApiAction.run(server_url: 'https://api.github.com',
                                                 path: "/search/issues?q=repo:#{org}/#{repo_name}+is:pr+base:main+SHA:#{sha}",
                                                 http_method: 'GET',
                                                 body: {},
                                                 api_token: github_token)
          body = JSON.parse(pr_resp[:body])
          items = body["items"]
          if items.size == 1
            item = items.first
            @@prs_by_sha[sha] ||= item

            message = "#{item['title']} (##{item['number']})"
            username = item["user"]["login"]
            types_of_change = item["labels"]
                              .map { |label_info| label_info["name"] }
                              .select { |label| SUPPORTED_PR_LABELS.include?(label) }
                              .to_set

            section = get_section_depending_on_types_of_change(types_of_change)

            line = "* #{message} via #{name} (@#{username})"
            changelog_sections[section].push(line)
          else
            UI.user_error!("Cannot generate changelog. Multiple commits found for #{sha}")
          end
        end

        build_changelog_sections(changelog_sections)
      end

      def self.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
        changelog_filename = File.basename(changelog_latest_path)

        UI.user_error!("Pre populated content for changelog was empty") if prepopulated_changelog.empty?

        UI.message("Using pre populated contents:\n#{prepopulated_changelog}")

        UI.message("Will use '#{editor}'... Override by setting FASTLANE_EDITOR environment variable")
        UI.user_error!("Cancelled") unless UI.confirm("Open #{changelog_filename} in '#{editor}'? (No will quit this process)")
        File.write(changelog_latest_path, prepopulated_changelog)

        system(editor, changelog_latest_path.shellescape)

        # Some people may use visual editors and `system` will continue right away.
        # This will compare the content before and afer attempting to open
        # and will open a blocking prompt for the visual editor changes to be saved
        content_after_opening_editor = File.read(changelog_latest_path)
        return unless prepopulated_changelog == content_after_opening_editor

        unless UI.confirm("You may have opened the changelog in a visual editor. Enter 'y' when changes are saved or 'n' to cancel")
          UI.user_error!("Cancelled")
        end
      end

      def self.attach_changelog_to_master(version_number, changelog_latest_path, changelog_path)
        current_changelog = File.open(changelog_latest_path, 'r')
        master_changelog = File.open(changelog_path, 'r')

        current_changelog_data = current_changelog.read
        master_changelog_data = master_changelog.read

        current_changelog.close
        master_changelog.close

        File.open(changelog_path, 'w') do |master_changelog_write_mode|
          version_header = "## #{version_number}"
          whole_file_data = "#{version_header}\n#{current_changelog_data}\n#{master_changelog_data}"

          master_changelog_write_mode.write(whole_file_data)
        end
      end

      def self.create_new_branch_and_checkout(branch_name)
        Actions.sh("git checkout -b '#{branch_name}'")
      end

      def self.commmit_changes_and_push_current_branch(commit_message)
        commit_current_changes(commit_message)
        Actions::PushToGitRemoteAction.run(remote: 'origin')
      end

      def self.create_pr_to_main(title, body, repo_name, github_pr_token)
        Actions::CreatePullRequestAction.run(
          api_token: github_pr_token,
          title: title,
          base: 'main',
          body: body,
          repo: "RevenueCat/#{repo_name}",
          head: Actions.git_branch,
          api_url: 'https://api.github.com'
        )
      end

      def self.validate_local_config_status_for_bump(branch, new_branch, github_pr_token)
        # Ensure GitHub API token is set
        if github_pr_token.nil? || github_pr_token.empty?
          UI.error("A github_pr_token parameter or an environment variable GITHUB_PULL_REQUEST_API_TOKEN is required to create a pull request")
          UI.error("Please make a fastlane/.env file from the fastlane/.env.SAMPLE template")
          UI.user_error!("Could not find value for GITHUB_PULL_REQUEST_API_TOKEN")
        end
        ensure_new_branch_local_remote(new_branch)
        Actions::EnsureGitBranchAction.run(branch: branch)
        Actions::EnsureGitStatusCleanAction.run({})
      end

      def self.calculate_next_snapshot_version(current_version)
        version_split = current_version.split('.')
        UI.user_error("Invalid version number: #{current_version}. Expected 3 numbers separated by '.'") if version_split.size != 3
        major = version_split[0]
        minor = version_split[1]
        next_version = "#{major}.#{minor.to_i + 1}.0"
        "#{next_version}-SNAPSHOT"
      end

      def self.create_github_release(release_version, release_description, upload_assets, repo_name, github_api_token)
        commit_hash = Actions.last_git_commit_dict[:commit_hash]
        is_prerelease = release_version.include?("-")

        Actions::SetGithubReleaseAction.run(
          repository_name: "RevenueCat/#{repo_name}",
          api_token: github_api_token,
          name: release_version,
          tag_name: release_version,
          description: release_description,
          commitish: commit_hash,
          upload_assets: upload_assets,
          is_draft: false,
          is_prerelease: is_prerelease,
          server_url: 'https://api.github.com'
        )
      end

      def self.replace_in(previous_text, new_text, path, allow_empty: false)
        if new_text.to_s.strip.empty? && !allow_empty
          UI.user_error!("Missing `new_text` in call to `replace_in`, looking for replacement for #{previous_text} 😵.")
        end
        original_text = File.read(path)
        replaced_text = original_text.gsub(previous_text, new_text)
        File.write(path, replaced_text)
      end

      def self.commit_current_changes(commit_message)
        Actions.sh('git add -u')
        Actions.sh("git commit -m '#{commit_message}'")
      end

      def self.get_github_release_tag_names(repo_name)
        response = Actions::GithubApiAction.run(
          server_url: "https://api.github.com",
          http_method: 'GET',
          path: "repos/RevenueCat/#{repo_name}/releases",
          error_handlers: {
            404 => proc do |result|
              UI.user_error!("Repository #{repo_name} cannot be found, please double check its name and that you provided a valid API token (if it's a private repository).")
            end,
            401 => proc do |result|
              UI.user_error!("You are not authorized to access #{repo_name}, please make sure you provided a valid API token.")
            end,
            '*' => proc do |result|
              UI.user_error!("GitHub responded with #{result[:status]}:#{result[:body]}")
            end
          }
        )
        json = response[:json]
        json.reject { |item| item["prerelease"] }
            .map { |item| item['tag_name'] }
      end

      private_class_method def self.ensure_new_branch_local_remote(new_branch)
        local_branches = Actions.sh('git', 'branch', '--list', new_branch)
        unless local_branches.empty?
          UI.error("Branch '#{new_branch}' already exists in local repository.")
          UI.user_error!("Please make sure it doesn't have any unsaved changes and delete it to continue.")
        end

        remote_branches = Actions.sh('git', 'ls-remote', '--heads', 'origin', new_branch)
        unless remote_branches.empty?
          UI.error("Branch '#{new_branch}' already exists in remote repository.")
          UI.user_error!("Please make sure it doesn't have any unsaved changes and delete it to continue.")
        end
      end

      private_class_method def self.build_changelog_sections(changelog_sections)
        changelog_sections.reject { |_, v| v.empty? }.map do |section_name, prs|
          next unless prs.size > 0

          case section_name
          when :breaking_changes
            title = "## Breaking Changes"
          when :fixes
            title = "## Bugfixes"
          when :new_features
            title = "## New Features"
          when :other
            title = "## Other Changes"
          else
            title = "## Other Changes"
          end
          "#{title}\n#{prs.join("\n")}"
        end.join("\n")
      end

      private_class_method def self.get_section_depending_on_types_of_change(change_types)
        if change_types.include?("breaking")
          :breaking_changes
        elsif change_types.include?("feat")
          :new_features
        elsif change_types.include?("fix")
          :fixes
        else
          :other
        end
      end
    end
  end
end
