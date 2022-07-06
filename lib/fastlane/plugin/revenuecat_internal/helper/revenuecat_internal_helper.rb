require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require 'fastlane/actions/push_to_git_remote'
require 'fastlane/actions/create_pull_request'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class RevenuecatInternalHelper
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

        commits.map do |commit|
          if rate_limit_sleep > 0
            UI.message("Sleeping #{rate_limit_sleep} second(s) to avoid rate limit 🐌")
            sleep(rate_limit_sleep)
          end

          # Default to commit message info
          message = commit["commit"]["message"].lines.first.strip
          name = commit["commit"]["author"]["name"]
          username = commit["author"]["login"]

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
            message = "#{item['title']} (##{item['number']})"
            username = item["user"]["login"]
          else
            UI.user_error!("Cannot generate changelog. Multiple commits found for #{sha}")
          end

          "* #{message} via #{name} (@#{username})"
        end.join("\n")
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

      def self.create_new_release_branch(release_version)
        Actions.sh("git checkout -b 'release/#{release_version}'")
      end

      def self.commmit_changes_and_push_current_branch(commit_message)
        Actions.sh('git add -u')
        Actions.sh("git commit -m '#{commit_message}'")
        Actions::PushToGitRemoteAction.run(remote: 'origin')
      end

      def self.create_release_pr(version_number, changelog, repo_name)
        github_pr_token = ENV.fetch('GITHUB_PULL_REQUEST_API_TOKEN', nil)
        Actions::CreatePullRequestAction.run(
          api_token: github_pr_token,
          title: "Release/#{version_number}",
          base: 'main',
          body: changelog,
          repo: repo_name,
          head: Actions.git_branch,
          api_url: 'https://api.github.com'
        )
      end

      def self.validate_local_config_status_for_bump(branch)
        ensure_git_branch(branch: branch)
        ensure_git_status_clean

        # Ensure GitHub API token is set
        github_pr_token = ENV.fetch('GITHUB_PULL_REQUEST_API_TOKEN', nil)
        if github_pr_token.nil? || github_pr_token.empty?
          UI.error("Environment variable GITHUB_PULL_REQUEST_API_TOKEN is required to create a pull request")
          UI.error("Please make a fastlane/.env file from the fastlane/.env.SAMPLE template")
          UI.user_error!("Could not find value for GITHUB_PULL_REQUEST_API_TOKEN")
        end
      end

      def self.replace_in(previous_text, new_text, path, allow_empty: false)
        if new_text.to_s.strip.empty? && !allow_empty
          UI.user_error!("Missing `new_text` in call to `replace_in`, looking for replacement for #{previous_text} 😵.")
        end
        sed_regex = "s|#{previous_text.sub('.', '\\.')}|#{new_text}|"
        backup_extension = '.bck'
        Actions.sh("sed", '-i', backup_extension, sed_regex, path)
      end
    end
  end
end
