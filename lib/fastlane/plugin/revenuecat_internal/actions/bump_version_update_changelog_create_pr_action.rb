require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'
require_relative '../helper/versioning_helper'

module Fastlane
  module Actions
    class BumpVersionUpdateChangelogCreatePrAction < Action
      # rubocop:disable Metrics/PerceivedComplexity
      def self.run(params)
        repo_name = params[:repo_name]
        github_pr_token = params[:github_pr_token]
        github_token = params[:github_token]
        rate_limit_sleep = params[:github_rate_limit]
        version_number = params[:current_version]
        new_version_number = params[:next_version]
        files_to_update = params[:files_to_update]
        files_to_update_without_prerelease_modifiers = params[:files_to_update_without_prerelease_modifiers]
        files_to_update_on_latest_stable_releases = params[:files_to_update_on_latest_stable_releases]
        changelog_latest_path = params[:changelog_latest_path]
        changelog_path = params[:changelog_path]
        editor = params[:editor]
        automatic_release = params[:automatic_release]
        hybrid_common_version = params[:hybrid_common_version]
        versions_file_path = params[:versions_file_path]
        include_prereleases = params[:is_prerelease]
        append_phc_version_if_next_version_is_not_prerelease = params[:append_phc_version_if_next_version_is_not_prerelease]
        enable_auto_merge = params[:enable_auto_merge]
        slack_url = params[:slack_url]
        dry_run = params[:dry_run]

        # See if we got any conflicting arguments.
        Helper::VersioningHelper.validate_input_if_appending_phc_version?(
          append_phc_version_if_next_version_is_not_prerelease,
          hybrid_common_version
        )

        current_branch = Actions.git_branch
        if dry_run
          UI.important("Dry run mode enabled. No changes will be made.")
          UI.important("Current branch is #{current_branch}")
        elsif UI.interactive? && !UI.confirm("Current branch is #{current_branch}. Are you sure this is the base branch for your bump?")
          UI.user_error!("Cancelled during branch confirmation")
        end

        UI.important("Current version is #{version_number}")

        # Ask for new version number
        new_version_number ||= UI.input("New version number: ")

        UI.user_error!("Version number cannot be empty") if new_version_number.strip.empty?
        Helper::VersioningHelper.validate_new_version_if_appending_phc_version?(
          append_phc_version_if_next_version_is_not_prerelease,
          new_version_number,
          hybrid_common_version
        )

        new_version_number = Helper::VersioningHelper.append_phc_version_if_necessary(
          append_phc_version_if_next_version_is_not_prerelease,
          include_prereleases,
          hybrid_common_version,
          new_version_number
        )

        UI.important("New version is #{new_version_number}")

        new_branch_name = "release/#{new_version_number}"

        Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump(new_branch_name, github_pr_token)

        if github_token && !github_token.empty?
          auth_status = Helper::GitHubHelper.check_authentication_and_rate_limits(github_token)
          unless auth_status[:authenticated]
            UI.user_error!("GitHub authentication failed.")
          end
        else
          UI.important("No github_token provided.")
        end

        generated_contents = Helper::VersioningHelper.auto_generate_changelog(repo_name, github_token, rate_limit_sleep, include_prereleases, hybrid_common_version, versions_file_path, new_version_number)

        if UI.interactive?
          Helper::RevenuecatInternalHelper.edit_changelog(generated_contents, changelog_latest_path, editor)
        else
          Helper::RevenuecatInternalHelper.write_changelog(generated_contents, changelog_latest_path)
        end

        changelog = File.read(changelog_latest_path)

        unless dry_run
          Helper::RevenuecatInternalHelper.create_new_branch_and_checkout(new_branch_name)
        end

        Helper::RevenuecatInternalHelper.replace_version_number(version_number,
                                                                new_version_number,
                                                                files_to_update,
                                                                files_to_update_without_prerelease_modifiers,
                                                                files_to_update_on_latest_stable_releases)
        Helper::RevenuecatInternalHelper.attach_changelog_to_main(new_version_number, changelog_latest_path, changelog_path)

        unless dry_run
          Helper::RevenuecatInternalHelper.commit_changes_and_push_current_branch("Version bump for #{new_version_number}")

          pr_title = "Release/#{new_version_number}"
          label = 'pr:next_release'
          body = changelog

          if automatic_release
            body = "**This is an automatic release.**\n\n#{body}"
            pr_title = "[AUTOMATIC] #{pr_title}"
          end

          Helper::RevenuecatInternalHelper.create_pr(pr_title, body, repo_name, current_branch, new_branch_name, github_pr_token, labels: [label], enable_auto_merge: enable_auto_merge || false, slack_url: slack_url)
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.description
        "Bumps sdk version, asks to update changelog and creates PR with changes."
      end

      def self.authors
        ["Toni Rico"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :current_version,
                                       description: "Current version of the SDK",
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
                                       description: 'Hash of files that contain the version number and need to have it ' \
                                                    'updated to the patterns that contains the version in the file. ' \
                                                    'Mark the version in the pattern using {x}. ' \
                                                    'For example: { "./pubspec.yaml" => ["version: {x}"] }',
                                       optional: false,
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :files_to_update_without_prerelease_modifiers,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_VERSION_WITHOUT_PRERELEASE_MODIFIERS",
                                       description: 'Hash of files that contain the version number without pre-release ' \
                                                    'modifier and need to have it updated, to the patterns that ' \
                                                    'contains the version in the file. ' \
                                                    'Mark the version in the pattern using {x}. ' \
                                                    'For example: { "./pubspec.yaml" => ["version: {x}"] }',
                                       optional: true,
                                       default_value: {},
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :files_to_update_on_latest_stable_releases,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_ON_LATEST_STABLE_RELEASES",
                                       description: 'Hash of files that contain the version number and only need to ' \
                                                    'be updated on stable releases (no prereleases) and on the latest ' \
                                                    'major (no hotfixes). Note that the version will be updated as ' \
                                                    'long as it matches a semver stable version, even if its not the previous version ' \
                                                    'Mark the version in the pattern using {x}. ' \
                                                    'For example: { "./pubspec.yaml" => ["version: {x}"] }',
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
                                       description: "Github token to use to create the release PR",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       env_name: "GITHUB_TOKEN",
                                       description: "Github token to use to prepopulate the changelog",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_rate_limit,
                                       env_name: "RC_INTERNAL_GITHUB_RATE_LIMIT_SLEEP",
                                       description: "Sets a rate limiter for github requests when creating the changelog",
                                       optional: true,
                                       default_value: 0,
                                       type: Integer),
          FastlaneCore::ConfigItem.new(key: :editor,
                                       env_name: "RC_INTERNAL_FASTLANE_EDITOR",
                                       description: "Allows to override editor to be used when editing the changelog",
                                       optional: true,
                                       default_value: "vim",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :next_version,
                                       description: "Next version of the SDK",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :automatic_release,
                                       description: "If this is an automatic release",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :hybrid_common_version,
                                       description: "Version of the hybrid common sdk to add to the VERSIONS.md file",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :versions_file_path,
                                       description: "Path to the VERSIONS.md file",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :is_prerelease,
                                       description: "If this is a prerelease",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :append_phc_version_if_next_version_is_not_prerelease,
                                       description: "Whether to append the hybrid_common_version to the new version number, if that new version number is not a pre-release version",
                                       optional: true,
                                       is_string: false,
                                       default_value: nil),
          FastlaneCore::ConfigItem.new(key: :enable_auto_merge,
                                       description: "Whether to enable auto-merge (squash) on the created PR",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :slack_url,
                                       env_name: "SLACK_URL_SDK_RELEASES",
                                       description: "Slack webhook URL to notify on auto-merge failures",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :dry_run,
                                       description: "Whether to run the action in dry run mode",
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
