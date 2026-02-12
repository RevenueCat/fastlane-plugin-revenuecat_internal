require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/github_helper'

module Fastlane
  module Actions
    class ValidatePrApprovedAction < Action
      def self.run(params)
        github_token = params[:github_token]
        pr_url = params[:pr_url]

        approved = Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)

        if approved
          UI.success("PR has been approved by an organization member with write permissions")
        else
          UI.user_error!("PR has not been approved by an organization member with write permissions")
        end
      end

      def self.description
        "Validates that the current PR is approved by an organization member with write permissions"
      end

      def self.authors
        ["RevenueCat"]
      end

      def self.return_value
        nil
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       env_name: "GITHUB_TOKEN",
                                       description: "GitHub API token",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :pr_url,
                                       env_name: "CIRCLE_PULL_REQUEST",
                                       description: "URL of the pull request to check",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
