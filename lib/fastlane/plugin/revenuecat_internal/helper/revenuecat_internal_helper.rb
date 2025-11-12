require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require 'fastlane/actions/push_to_git_remote'
require 'fastlane/actions/create_pull_request'
require 'fastlane/actions/ensure_git_branch'
require 'fastlane/actions/ensure_git_status_clean'
require 'fastlane/actions/reset_git_repo'
require_relative 'versioning_helper'
require_relative 'github_helper'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class RevenuecatInternalHelper
      def self.replace_version_number(previous_version_number,
                                      new_version_number,
                                      files_to_update_with_patterns,
                                      files_to_update_without_prerelease_modifiers,
                                      files_to_update_on_latest_stable_releases)
        # Strip whitespace from version numbers to handle newlines from .version files
        previous_version_number = previous_version_number.to_s.strip
        new_version_number = new_version_number.to_s.strip

        previous_version_number_without_prerelease_modifiers = previous_version_number.split(DELIMITER_PRERELEASE)[0]
        new_version_number_without_prerelease_modifiers = new_version_number.split(DELIMITER_PRERELEASE)[0]
        files_to_update_with_patterns.each do |file_to_update, patterns|
          replace_in(previous_version_number, new_version_number, file_to_update, patterns)
        end
        files_to_update_without_prerelease_modifiers.each do |file_to_update, patterns|
          replace_in(previous_version_number_without_prerelease_modifiers, new_version_number_without_prerelease_modifiers, file_to_update, patterns)
        end
        if !files_to_update_on_latest_stable_releases.empty? && newer_than_or_equal_to_latest_published_version?(new_version_number) && !Gem::Version.new(drop_build_metadata(new_version_number)).prerelease?
          files_to_update_on_latest_stable_releases.each do |file_to_update, patterns|
            replace_stable_version_number_using_regex(new_version_number_without_prerelease_modifiers, file_to_update, patterns)
          end
        end
      end

      def self.newer_than_or_equal_to_latest_published_version?(version_number)
        latest_published_version = get_latest_published_version_number
        return true if latest_published_version.empty?

        Gem::Version.new(drop_build_metadata(latest_published_version)) <= Gem::Version.new(drop_build_metadata(version_number))
      end

      def self.older_than_latest_published_version?(version_number)
        return !newer_than_or_equal_to_latest_published_version?(version_number)
      end

      def self.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
        changelog_filename = File.basename(changelog_latest_path)

        UI.message("Warning: pre-populated content for changelog is empty") if prepopulated_changelog.empty?
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

      def self.write_changelog(prepopulated_changelog, changelog_latest_path)
        UI.user_error!("Pre populated content for changelog was empty") if prepopulated_changelog.empty?

        UI.message("Using pre populated contents:\n#{prepopulated_changelog}")

        # An extra line at the end needs to be added. Vim adds it automatically.
        File.write(changelog_latest_path, "#{prepopulated_changelog}\n")
      end

      def self.attach_changelog_to_main(version_number, changelog_latest_path, changelog_path)
        current_changelog = File.open(changelog_latest_path, 'r')
        main_changelog = File.open(changelog_path, 'r')

        current_changelog_data = current_changelog.read
        main_changelog_data = main_changelog.read

        current_changelog.close
        main_changelog.close

        File.open(changelog_path, 'w') do |main_changelog_write_mode|
          version_header = "## #{version_number}"
          whole_file_data = "#{version_header}\n#{current_changelog_data}\n#{main_changelog_data}"

          main_changelog_write_mode.write(whole_file_data)
        end
      end

      def self.insert_old_version_changelog_in_current_branch(version_number, old_version_changelog_contents, changelog_path)
        main_changelog_data = File.read(changelog_path)

        version_header = "## #{version_number}"
        data_to_insert = "#{version_header}\n#{old_version_changelog_contents}\n" # changelog.latest usually ends with a newline already

        # Compare versions ignoring prerelease and build metadata.
        new_core_version = Gem::Version.new(get_core_version(version_number))

        # Match a version header line. Allow optional extra text for prerelease/build metadata,
        # but require it to be a standalone header line ("## <semver...>").
        #
        # Captures the FULL version string (which might include -prerelease and/or +build)
        # in group 1, so we can strip it down to core for comparison.
        header_regex = /^##\s+(\d+\.\d+\.\d+(?:[#{Regexp.escape(DELIMITER_PRERELEASE + DELIMITER_BUILD_METADATA)}][^\s]*)?)\s*$/

        output = +""
        inserted = false

        main_changelog_data.each_line do |line|
          if !inserted && (m = line.match(header_regex))
            current_full = m[1]
            current_core = Gem::Version.new(get_core_version(current_full))

            if current_full == version_number
              UI.user_error!("Changelog already contains an entry for version #{version_number}")
            end

            # Insert right before the first header whose version is smaller
            if current_core < new_core_version
              output << data_to_insert
              inserted = true
            end
          end

          output << line
        end

        # If nothing smaller was found, append at the end
        unless inserted
          output << "\n" unless output.end_with?("\n")
          output << data_to_insert
        end

        File.write(changelog_path, output)
        true
      end

      def self.create_new_branch_and_checkout(branch_name)
        Actions.sh("git checkout -b '#{branch_name}'")
      end

      def self.create_or_checkout_branch(branch_name)
        branch_exists_locally = Actions.sh("git", "branch", "--list", branch_name).length > 0
        branch_exists_remotely = Actions.sh("git", "ls-remote", "--heads", "origin", branch_name).length > 0

        if branch_exists_locally || branch_exists_remotely
          UI.message("Branch #{branch_name} already exists, checking it out")
          Actions.sh("git checkout '#{branch_name}'")
          if branch_exists_remotely
            Actions.sh("git pull 'origin' '#{branch_name}'")
          end
        else
          UI.message("Creating new branch #{branch_name}")
          Actions.sh("git checkout -b '#{branch_name}'")
        end
      end

      def self.commit_changes_and_push_current_branch(commit_message)
        commit_current_changes(commit_message)
        Actions::PushToGitRemoteAction.run(remote: 'origin')
      end

      def self.create_pr(title, body, repo_name, base_branch, head_branch, github_pr_token, labels = [])
        Actions::CreatePullRequestAction.run(
          api_token: github_pr_token,
          title: title,
          base: base_branch,
          body: body,
          repo: "RevenueCat/#{repo_name}",
          head: head_branch,
          api_url: 'https://api.github.com',
          labels: labels,
          team_reviewers: ['coresdk']
        )
      end

      def self.create_pr_if_necessary(title, body, repo_name, base_branch, head_branch, github_pr_token, labels = [], team_reviewers = ['coresdk'])
        repo_with_owner = "RevenueCat/#{repo_name}"
        existing_pr = Helper::GitHubHelper.github_api_call_with_retry(
          api_token: github_pr_token,
          path: "/repos/#{repo_with_owner}/pulls?head=RevenueCat:#{head_branch}&state=open"
        )

        if existing_pr[:json].length == 0
          pr_url = Actions::CreatePullRequestAction.run(
            repo: repo_with_owner,
            title: title,
            body: body,
            base: base_branch,
            head: head_branch,
            api_token: github_pr_token,
            labels: labels,
            team_reviewers: team_reviewers
          )

          if pr_url.nil?
            UI.user_error!("Failed to create pull request.")
          end
        else
          UI.message("PR already exists.")
        end
      end

      def self.validate_local_config_status_for_bump(new_branch, github_pr_token)
        # Ensure GitHub API token is set
        if github_pr_token.nil? || github_pr_token.empty?
          UI.error("A github_pr_token parameter or an environment variable GITHUB_PULL_REQUEST_API_TOKEN is required to create a pull request")
          UI.error("Please make a fastlane/.env file from the fastlane/.env.SAMPLE template")
          UI.user_error!("Could not find value for GITHUB_PULL_REQUEST_API_TOKEN")
        end
        ensure_new_branch_local_remote(new_branch)
        if UI.interactive?
          Actions::EnsureGitStatusCleanAction.run(
            show_diff: true
          )
        else
          if self.is_git_repo_dirty
            UI.message("Git status is not clean. Resetting all files.")
            Actions::ResetGitRepoAction.run(force: true)
          end
        end
      end

      def self.is_git_repo_dirty
        git_status = Actions.sh("git status --porcelain", log: true, error_callback: ->(_) {})
        return git_status.lines.length > 0
      end

      def self.calculate_next_snapshot_version(current_version)
        Helper::VersioningHelper.calculate_next_version(current_version, :minor, true)
      end

      def self.create_github_release(release_version, release_description, upload_assets, repo_name, github_api_token, draft: false)
        commit_hash = Actions.last_git_commit_dict[:commit_hash]
        is_prerelease = release_version.include?(DELIMITER_PRERELEASE)
        is_latest_stable_release = !is_prerelease && newer_than_or_equal_to_latest_published_version?(release_version)

        # This is a temporary workaround as the fastlane action does not support the `make_latest` parameter
        # Forked from: https://github.com/fastlane/fastlane/blob/master/fastlane/lib/fastlane/actions/set_github_release.rb
        Helper::GitHubHelper.create_github_release(
          repository_name: "RevenueCat/#{repo_name}",
          api_token: github_api_token,
          name: release_version,
          tag_name: release_version,
          description: release_description,
          commitish: commit_hash,
          upload_assets: upload_assets,
          is_draft: draft,
          is_prerelease: is_prerelease,
          make_latest: is_latest_stable_release,
          server_url: 'https://api.github.com'
        )
      end

      def self.replace_in(previous_text, new_text, path, patterns = ['{x}'], allow_empty: false)
        if new_text.to_s.strip.empty? && !allow_empty
          UI.user_error!("Missing `new_text` in call to `replace_in`, looking for replacement for #{previous_text} 😵.")
        end
        original_text = File.read(path)
        replaced_text = original_text
        patterns.each do |pattern|
          replaced_previous_text = pattern.gsub('{x}', previous_text)
          replaced_new_text = pattern.gsub('{x}', new_text)
          replaced_text = replaced_text.gsub(replaced_previous_text, replaced_new_text)
        end

        File.write(path, replaced_text)
      end

      def self.commit_current_changes(commit_message)
        Actions.sh('git add -u')
        Actions.sh("git commit -m '#{commit_message}'")
      end

      def self.commit_all_changes(commit_message)
        if Actions.sh("git", "status", "--porcelain").empty?
          UI.message("No changes to commit")
        else
          commit_changes = lambda do
            Actions.sh("git", "add", "--all", ".")
            Actions.sh("git", "commit", "-m", commit_message)
          end
          # Assume any fastlane directory is a subdirectory of the root directory.
          if File.basename(Dir.pwd) == "fastlane"
            Dir.chdir("..") { commit_changes.call }
          else
            commit_changes.call
          end
        end
      end

      def self.discard_changes_in_current_branch
        Actions.sh("git restore .")
      end

      def self.get_github_release_tag_names(repo_name, github_token = nil)
        response = Helper::GitHubHelper.github_api_call_with_retry(
          server_url: "https://api.github.com",
          http_method: 'GET',
          path: "repos/RevenueCat/#{repo_name}/releases",
          api_token: github_token,
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

      def self.git_clone_source_to_dest(source_repo, destination_repo)
        Actions.sh("git clone #{source_repo}")
        repo_name = source_repo.split('/').last.gsub('.git', '')

        Dir.chdir(repo_name) do
          Actions.sh("git fetch --tags")
          Actions.sh("git remote set-url origin #{destination_repo}")

          Actions.sh("git push origin")
          Actions.sh("git push --tags")
        end
      end

      private_class_method def self.ensure_new_branch_local_remote(new_branch)
        local_branches = Actions.sh('git', 'branch', '--list', new_branch)
        unless local_branches.empty?
          UI.error("Branch '#{new_branch}' already exists in local repository.")
          UI.user_error!("Please make sure it doesn't have any unsaved changes and delete it to continue.")
        end

        remote_branches = Actions.sh('git', 'ls-remote', '--heads', 'origin', new_branch)
        if !remote_branches.nil? && remote_branches.include?(new_branch)
          UI.error("Branch '#{new_branch}' already exists in remote repository.")
          UI.user_error!("Please make sure it doesn't have any unsaved changes and delete it to continue.")
        end
      end

      private_class_method def self.replace_stable_version_number_using_regex(new_text, path, patterns = ['{x}'])
        original_text = File.read(path)
        replaced_text = original_text
        semver_regex = /(\d+\.\d+\.\d+)(\\+(#{PATTERN_BUILD_METADATA}))?/o
        patterns.each do |pattern|
          previous_regex = Regexp.new(pattern.gsub('{x}', semver_regex.source))
          replaced_new_text = pattern.gsub('{x}', new_text)
          replaced_text = replaced_text.gsub(previous_regex, replaced_new_text)
        end

        File.write(path, replaced_text)
      end

      private_class_method def self.drop_build_metadata(version)
        version.split(DELIMITER_BUILD_METADATA)[0]
      end

      private_class_method def self.drop_prerelease_modifiers(version)
        version.split(DELIMITER_PRERELEASE)[0]
      end

      # This is the core version of the given version, without prerelease or build metadata
      private_class_method def self.get_core_version(version)
        drop_build_metadata(drop_prerelease_modifiers(version))
      end

      # rubocop:disable Naming/AccessorMethodName
      private_class_method def self.get_latest_published_version_number
        Actions.sh("git tag | grep '^[0-9]*\.[0-9]*\.[0-9]*$' | sort -r --version-sort | head -n1")
      end
      # rubocop:enable Naming/AccessorMethodName
    end
  end
end
