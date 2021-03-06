require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class CreateNextSnapshotVersionAction < Action
      def self.run(params)
        previous_version_number = params[:current_version]
        repo_name = params[:repo_name]
        github_pr_token = params[:github_pr_token]
        files_to_update = params[:files_to_update]
        files_to_update_without_prerelease_modifiers = params[:files_to_update_without_prerelease_modifiers]
        branch = params[:branch]

        next_version_snapshot = Helper::RevenuecatInternalHelper.calculate_next_snapshot_version(previous_version_number)
        new_branch_name = "bump/#{next_version_snapshot}"

        Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump(branch, new_branch_name, github_pr_token)

        Helper::RevenuecatInternalHelper.create_new_branch_and_checkout(new_branch_name)

        Helper::RevenuecatInternalHelper.replace_version_number(previous_version_number,
                                                                next_version_snapshot,
                                                                files_to_update,
                                                                files_to_update_without_prerelease_modifiers)

        Helper::RevenuecatInternalHelper.commmit_changes_and_push_current_branch('Preparing for next version')

        Helper::RevenuecatInternalHelper.create_pr_to_main("Prepare next version: #{next_version_snapshot}", nil, repo_name, github_pr_token)
      end

      def self.description
        "Bumps minor version and adds -SNAPSHOT suffix to version. Creates a PR with the changes"
      end

      def self.authors
        ["Toni Rico"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :current_version,
                                       description: "Current version of the sdk",
                                       optional: false,
                                       type: String),
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
          FastlaneCore::ConfigItem.new(key: :files_to_update,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_VERSION",
                                       description: "Files that contain the version number and need to have it updated",
                                       optional: false,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :files_to_update_without_prerelease_modifiers,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_VERSION_WITHOUT_PRERELEASE_MODIFIERS",
                                       description: "Files that contain the version number without release modifiers and need to have it updated",
                                       optional: true,
                                       default_value: [],
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :branch,
                                       description: "Allows to execute the action from the given branch",
                                       optional: true,
                                       default_value: "main",
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
