require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/github_helper'

module Fastlane
  module Actions
    class CheckPrApprovedAction < Action
      def self.run(params)
        github_token = params[:github_token]
        pr_url = params[:pr_url]

        if pr_url.nil? || pr_url.to_s.empty?
          UI.user_error!("PR URL is required. Set CIRCLE_PULL_REQUEST environment variable or pass pr_url parameter.")
        end

        Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      end

      def self.description
        "Checks if the current PR is approved by an organization member with write permissions"
      end

      def self.authors
        ["RevenueCat"]
      end

      def self.return_value
        "Boolean indicating whether the PR is approved by an org member with write permissions"
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
