require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'
require_relative '../helper/versioning_helper'

module Fastlane
  module Actions
    class BumpPhcVersionAction < Action
      def self.run(params)
        version_number = params[:current_version]
        files_to_update = params[:files_to_update]
        repo_name = params[:repo_name]
        github_pr_token = params[:github_pr_token]
        new_version_number = params[:next_version]
        automatic_release = params[:automatic_release]
        open_pr = params[:open_pr]

        UI.important("Current version is #{version_number}")

        # Ask for new version number
        new_version_number ||= UI.input("New version number: ")

        UI.user_error!("Version number cannot be empty") if new_version_number.strip.empty?
        UI.important("New version is #{new_version_number}")

        new_branch_name = "bump-phc/#{new_version_number}"

        if open_pr
          current_branch = Actions.git_branch
          if UI.interactive? && !UI.confirm("Current branch is #{current_branch}. Are you sure this is the base branch for your bump?")
            UI.user_error!("Cancelled during branch confirmation")
          end

          Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump(new_branch_name, github_pr_token)

          Helper::RevenuecatInternalHelper.create_new_branch_and_checkout(new_branch_name)
        end

        Helper::RevenuecatInternalHelper.replace_version_number(version_number,
                                                                new_version_number,
                                                                files_to_update,
                                                                [])

        return unless open_pr

        open_pr_against_main(automatic_release, github_pr_token, new_branch_name, new_version_number, repo_name, version_number)
      end

      def self.description
        "Bumps purchases-hybrid-common dependency version and creates PR with changes."
      end

      def self.authors
        ["César de la Vega"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :current_version,
                                       description: "Current version of the SDK",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :files_to_update,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_VERSION",
                                       description: "Files that contain the version number and need to have it updated",
                                       optional: false,
                                       type: Array),
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
          FastlaneCore::ConfigItem.new(key: :next_version,
                                       description: "Next version of the SDK",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :automatic_release,
                                       description: "If this is an automatic release",
                                       optional: true,
                                       is_string: false,
                                       default_value: false),
          FastlaneCore::ConfigItem.new(key: :open_pr,
                                       description: "If a branch should be created and a new PR should be opened with the dependency update",
                                       optional: true,
                                       is_string: false,
                                       default_value: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end

      private_class_method def self.open_pr_against_main(automatic_release, github_pr_token, new_branch_name, new_version_number, repo_name, version_number)
        Helper::RevenuecatInternalHelper.commit_changes_and_push_current_branch("Version bump for #{new_version_number}")

        pr_title = "Updates purchases-hybrid-common to #{new_version_number}"
        type_of_bump = Helper::VersioningHelper.detect_bump_type(version_number, new_version_number)
        labels = ['phc_dependencies']
        labels << 'minor' if type_of_bump == :minor
        body = pr_title
        base_branch = "main"

        if automatic_release
          body = "**This is an automatic bump.**\n\n#{body}"
          pr_title = "[AUTOMATIC BUMP] #{pr_title}"
        end

        Helper::RevenuecatInternalHelper.create_pr(pr_title, body, repo_name, base_branch, new_branch_name, github_pr_token, labels)
      end
    end
  end
end
