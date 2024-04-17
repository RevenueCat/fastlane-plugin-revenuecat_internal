require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'
require_relative '../helper/versioning_helper'

module Fastlane
  module Actions
    class BumpVersionUpdateChangelogCreatePrAction < Action
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

        current_branch = Actions.git_branch
        if UI.interactive? && !UI.confirm("Current branch is #{current_branch}. Are you sure this is the base branch for your bump?")
          UI.user_error!("Cancelled during branch confirmation")
        end

        UI.important("Current version is #{version_number}")

        # Ask for new version number
        new_version_number ||= UI.input("New version number: ")

        UI.user_error!("Version number cannot be empty") if new_version_number.strip.empty?
        UI.important("New version is #{new_version_number}")

        new_branch_name = "release/#{new_version_number}"

        Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump(new_branch_name, github_pr_token)

        generated_contents = Helper::VersioningHelper.auto_generate_changelog(repo_name, github_token, rate_limit_sleep, include_prereleases, hybrid_common_version, versions_file_path)

        if UI.interactive?
          Helper::RevenuecatInternalHelper.edit_changelog(generated_contents, changelog_latest_path, editor)
        else
          Helper::RevenuecatInternalHelper.write_changelog(generated_contents, changelog_latest_path)
        end

        changelog = File.read(changelog_latest_path)

        Helper::RevenuecatInternalHelper.create_new_branch_and_checkout(new_branch_name)
        Helper::RevenuecatInternalHelper.replace_version_number(version_number,
                                                                new_version_number,
                                                                files_to_update,
                                                                files_to_update_without_prerelease_modifiers,
                                                                files_to_update_on_latest_stable_releases)
        Helper::RevenuecatInternalHelper.attach_changelog_to_master(new_version_number, changelog_latest_path, changelog_path)
        Helper::RevenuecatInternalHelper.commit_changes_and_push_current_branch("Version bump for #{new_version_number}")

        pr_title = "Release/#{new_version_number}"
        label = 'next_release'
        body = changelog

        if automatic_release
          body = "**This is an automatic release.**\n\n#{body}"
          pr_title = "[AUTOMATIC] #{pr_title}"
        end

        Helper::RevenuecatInternalHelper.create_pr(pr_title, body, repo_name, current_branch, new_branch_name, github_pr_token, [label])
      end

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
                                       description: 'Hash of files that contain the version number and need to have it' \
                                                    'updated to the patterns that contains the version in the file.' \
                                                    'Mark the version in the pattern using {x}.' \
                                                    'For example: { "./pubspec.yaml" => ["version: {x}"] }',
                                       optional: false,
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :files_to_update_without_prerelease_modifiers,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_VERSION_WITHOUT_PRERELEASE_MODIFIERS",
                                       description: 'Hash of files that contain the version number without pre-release' \
                                                    'modifier and need to have it updated, to the patterns that' \
                                                    'contains the version in the file.' \
                                                    'Mark the version in the pattern using {x}.' \
                                                    'For example: { "./pubspec.yaml" => ["version: {x}"] }',
                                       optional: true,
                                       default_value: {},
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :files_to_update_on_latest_stable_releases,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_ON_LATEST_STABLE_RELEASES",
                                       description: 'Hash of files that contain the version number and only need to' \
                                                    'be updated on stable releases (no prereleases) and on the latest' \
                                                    'major (no hotfixes).' \
                                                    'Mark the version in the pattern using {x}.' \
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
                                       env_name: "RC_INTERNAL_GITHUB_TOKEN",
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
                                       description: "Allows to override editor to be used when editting the changelog",
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
                                       default_value: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
