require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/revenuecat_internal_helper'
require_relative '../helper/github_helper'

module Fastlane
  module Actions
    class GetLatestReleaseBeforeVersionAction < Action
      def self.run(params)
        repo_name = params[:repo_name]
        version = params[:version]
        current = Gem::Version.new(version.split("-").first)

        response = Helper::GitHubHelper.github_api_call_with_retry(
          server_url: "https://api.github.com",
          http_method: "GET",
          path: "/repos/RevenueCat/#{repo_name}/releases?per_page=100",
          body: {},
          api_token: params[:github_token]
        )
        releases = response[:json]
                   .reject { |release| release["draft"] || release["prerelease"] }
                   .map { |release| release["tag_name"] }
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
        "Reads the repository's GitHub releases, ignoring drafts and prereleases. Any prerelease suffix of the given " \
          "version is ignored too, so both 5.93.0-SNAPSHOT and 5.93.0 return the latest 5.92.x release. " \
          "Useful to find the release a build of the current branch is an update from, e.g. for SDK update tests."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       description: "The name of the RevenueCat repository to read the releases from, e.g. 'purchases-android'",
                                       type: String,
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("Please only pass the repository name, e.g. 'purchases-android'") if value.include?("github.com") || value.include?("/")
                                       end),
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "The version to find the previous release of, e.g. '5.93.0-SNAPSHOT'",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       env_name: "GITHUB_TOKEN",
                                       description: "GitHub token, to avoid the lower rate limits of unauthenticated requests",
                                       type: String,
                                       optional: true,
                                       sensitive: true)
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
          'release_version = get_latest_release_before_version(repo_name: "purchases-ios", version: "5.93.0-SNAPSHOT")'
        ]
      end

      def self.category
        :source_control
      end
    end
  end
end
