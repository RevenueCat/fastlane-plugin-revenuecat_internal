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
        skip_if_no_public_changes = params[:skip_if_no_public_changes]

        Helper::VersioningHelper.determine_next_version_using_labels(repo_name, github_token, rate_limit_sleep, skip_if_no_public_changes)
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
          FastlaneCore::ConfigItem.new(key: :skip_if_no_public_changes,
                                       env_name: "RC_INTERNAL_SKIP_IF_NO_PUBLIC_CHANGES",
                                       description: "Skip next version if no public changes have been commited to the repo. For example, if the only changes have been changes to CI, there shouldn't be a next release",
                                       optional: true,
                                       default_value: false,
                                       type: Boolean)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
