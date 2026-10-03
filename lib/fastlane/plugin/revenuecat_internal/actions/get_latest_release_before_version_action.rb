require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class GetLatestReleaseBeforeVersionAction < Action
      def self.run(params)
        repo_name = params[:repo_name]
        version = params[:version]
        current = Gem::Version.new(version.split("-").first)

        tags = Actions.sh("git", "ls-remote", "--tags", "--refs", "https://github.com/RevenueCat/#{repo_name}.git", log: false)
        releases = tags.lines
                       .map { |line| line.split("refs/tags/").last.strip }
                       .grep(/\A\d+\.\d+\.\d+\z/)
                       .map { |tag| Gem::Version.new(tag) }
                       .select { |release| release < current }
        UI.user_error!("No release of #{repo_name} found before #{version}") if releases.empty?

        latest_release = releases.max.to_s
        UI.message("Latest release of #{repo_name} before #{version}: #{latest_release}")
        latest_release
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Returns the highest stable release of a RevenueCat repository lower than the given version"
      end

      def self.details
        "Reads the repository's git tags, ignoring prerelease tags. Any prerelease suffix of the given version is " \
          "ignored too, so both 5.93.0-SNAPSHOT and 5.93.0 return the latest 5.92.x release. " \
          "Useful to find the release a build of the current branch is an update from, e.g. for SDK update tests."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       description: "The name of the RevenueCat repository to read the release tags from, e.g. 'purchases-android'",
                                       type: String,
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("Please only pass the repository name, e.g. 'purchases-android'") if value.include?("github.com") || value.include?("/")
                                       end),
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "The version to find the previous release of, e.g. '5.93.0-SNAPSHOT'",
                                       type: String,
                                       optional: false)
        ]
      end

      def self.return_value
        "The latest release version lower than the given version, e.g. '5.92.0'"
      end

      def self.authors
        ["Antonio Pallares"]
      end

      def self.is_supported?(platform)
        true
      end

      def self.example_code
        [
          'release_version = get_latest_release_before_version(repo_name: "purchases-ios-spm", version: "5.93.0-SNAPSHOT")'
        ]
      end

      def self.category
        :source_control
      end
    end
  end
end
