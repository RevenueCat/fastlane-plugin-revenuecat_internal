require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'
require_relative '../helper/versioning_helper'

module Fastlane
  module Actions
    class DetermineNextVersionUsingLabelsAction < Action
      def self.run(params)
        repo_name = params[:repo_name]
        github_token = params[:github_token]
        rate_limit_sleep = params[:github_rate_limit]
        include_prereleases = false
        current_version = params[:current_version]

        Helper::VersioningHelper.determine_next_version_using_labels(repo_name, github_token, rate_limit_sleep, include_prereleases, current_version)
      end

      def self.description
        "Determines next version using the labels of the pull requests merged since the last release. Returns the next version number along with the type of bump."
      end

      def self.authors
        ["Cesar de la Vega"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       env_name: "RC_INTERNAL_REPO_NAME",
                                       description: "Name of the repo of the SDK",
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
          FastlaneCore::ConfigItem.new(key: :current_version,
                                       description: "Current version of the SDK",
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
