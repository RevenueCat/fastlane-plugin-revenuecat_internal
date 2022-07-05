require 'fastlane_core/ui/ui'
require 'fastlane/action'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class RevenuecatHelper
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

      def self.auto_generate_changelog(repo_name, old_version, github_token, rate_limit_sleep, verbose)
        last_version = Actions.sh("git describe --tags --abbrev=0").strip
        old_version ||= last_version
        UI.important("Auto-generating changelog since #{old_version}")

        org = "RevenueCat"

        path = "/repos/#{org}/#{repo_name}/compare/#{old_version}...HEAD"

        # Get all commits from previous version (tag) to HEAD
        resp = github_api(path: path, api_token: github_token)
        body = JSON.parse(resp[:body])
        commits = body["commits"].reverse

        formatted = commits.map do |commit|
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
          pr_resp = github_api(path: "/search/issues?q=repo:#{org}/#{repo_name}+is:pr+base:main+SHA:#{sha}", api_token: github_token)
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

        puts(formatted) if verbose

        formatted
      end

      def self.edit_changelog(generated_contents, changelog_path, editor)
        changelog_filename = File.basename(changelog_path)
        content_before_opening_editor = File.read(changelog_path)

        if generated_contents.size > 0
          UI.message("Using auto generated contents:\n#{generated_contents}")
          File.write(changelog_path, generated_contents)
        else
          UI.user_error!("Generated content for changlog was empty")
        end

        UI.message("Will use '#{editor}'... Override by setting FASTLANE_EDITOR environment variable")
        if UI.confirm("Open #{changelog_filename} in '#{editor}'? (No will quit this process)")
          system(editor, changelog_path.shellescape)
        else
          UI.user_error!("Cancelled")
        end

        # Some people may use visual editors and `system` will continue right away.
        # This will compare the content before and afer attempting to open
        # and will open a blocking prompt for the visual editor changes to be saved
        content_after_opening_editor = File.read(changelog_path)
        return unless content_before_opening_editor == content_after_opening_editor

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
        Actions.sh("git add -u")
        Actions.sh("git commit -m '#{commit_message}'")
        push_to_git_remote
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
