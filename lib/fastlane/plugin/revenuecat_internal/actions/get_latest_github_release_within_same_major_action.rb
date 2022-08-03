require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class GetLatestGithubReleaseWithinSameMajorAction < Action
      def self.run(params)
        repo_name = params[:repo_name]
        current_version = Gem::Version.new(params[:current_version])
        UI.message("Getting latest release for #{repo_name} on GitHub within same major as #{current_version}")
        tag_names = Helper::RevenuecatInternalHelper.get_github_release_tag_names(repo_name)
        if tag_names.count == 0
          UI.user_error!("Couldn't find any GitHub release for #{params[:repo_name]}")
        end

        highest_version = tag_names.map { |tag_name| Gem::Version.new(tag_name) }
                                   .select { |item_version| same_major_range?(item_version, current_version) }
                                   .max

        UI.user_error!("Couldn't find any github release with same major as #{current_version}") if highest_version.nil?

        version_number = highest_version.version
        UI.message("Version #{version_number} is latest release in the same major live on GitHub.com 🚁")
        version_number
      end

      private_class_method def self.same_major_range?(version_a, version_b)
        version_a.canonical_segments[0] == version_b.canonical_segments[0]
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "This will get latest release version that is available on GitHub within the same major as the version given as parameter"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       env_name: "RC_INTERNAL_REPO_NAME",
                                       description: "The name of your RevenueCat repository, e.g. 'purchases-ios'",
                                       type: String,
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("Please only pass the repository name, e.g. 'purchases-ios'") if value.include?("github.com")
                                         UI.user_error!("Please only pass the repository name, e.g. 'purchases-ios'") if value.split('/').count != 1
                                       end),
          FastlaneCore::ConfigItem.new(key: :current_version,
                                       env_name: "RC_INTERNAL_CURRENT_VERSION",
                                       type: String,
                                       optional: false,
                                       description: "The current release version to check for next minor or patch")
        ]
      end

      def self.authors
        ["vegaro"]
      end

      def self.is_supported?(platform)
        true
      end

      def self.example_code
        [
          'release_name = get_latest_github_release_within_same_major(repo_name: "fastlane/fastlane")
          puts release_name'
        ]
      end

      def self.category
        :source_control
      end
    end
  end
end
