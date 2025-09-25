require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/github_helper'

module Fastlane
  module Actions
    class CheckGithubAuthenticationAction < Action
      def self.run(params)
        github_token = params[:github_token]

        auth_status = Helper::GitHubHelper.check_authentication_and_rate_limits(github_token)

        unless auth_status[:authenticated]
          UI.message("- Set environment variable")
          UI.message("- Ensure your token has the required permissions")
          UI.message("- Check that the token hasn't expired")
          if github_token && github_token.length > 4
            UI.message("- Token ending in: ...#{github_token[-4..]}")
          end
        end

        auth_status
      end

      def self.description
        "Checks GitHub authentication status and current rate limits"
      end

      def self.authors
        ["RevenueCat"]
      end

      def self.return_value
        "Hash containing authentication status and rate limit information"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       env_name: "GITHUB_TOKEN",
                                       description: "GitHub token to check authentication for",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
