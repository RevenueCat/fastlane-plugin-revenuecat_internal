require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class CreateGithubReleaseAction < Action
      def self.run(params)
        release_version = params[:version]
        repo_name = params[:repo_name]
        github_api_token = params[:github_api_token]
        changelog_latest_path = params[:changelog_latest_path]
        upload_assets = params[:upload_assets]

        begin
          changelog = File.read(changelog_latest_path)
        rescue StandardError
          UI.user_error!("Please add a CHANGELOG.latest.md file before calling this lane")
        end

        Helper::RevenuecatInternalHelper.create_github_release(
          release_version,
          changelog,
          upload_assets,
          repo_name,
          github_api_token
        )
      end

      def self.description
        "Bumps minor version and adds -SNAPSHOT suffix to version. Creates a PR with the changes"
      end

      def self.authors
        ["Toni Rico"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Version of the SDK to release",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       env_name: "RC_INTERNAL_REPO_NAME",
                                       description: "Name of the repo of the SDK",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_api_token,
                                       env_name: "RC_INTERNAL_GITHUB_TOKEN",
                                       description: "Github token to use to create the release",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :changelog_latest_path,
                                       description: "Path to CHANGELOG.latest.md file",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :upload_assets,
                                       description: "Array of paths to assets to upload in the release",
                                       optional: true,
                                       default_value: [],
                                       type: Array)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
