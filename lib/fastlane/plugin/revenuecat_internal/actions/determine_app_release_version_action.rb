require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/app_release_train_helper'

module Fastlane
  module Actions
    class DetermineAppReleaseVersionAction < Action
      def self.run(params)
        Helper::AppReleaseTrainHelper.next_release_version(
          params[:repo_name],
          params[:github_token],
          params[:current_version],
          major_bump_labels: params[:major_bump_labels],
          minor_bump_labels: params[:minor_bump_labels],
          patch_bump_labels: params[:patch_bump_labels],
          changelog_ignore_label: params[:changelog_ignore_label]
        )
      end

      def self.description
        "Determines the next app release version from the labels of PRs merged since the last published GitHub release (tagged <version>-<build>). Returns the next version string."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.return_value
        "The next release version string, e.g. 1.2.3"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       env_name: "RC_INTERNAL_REPO_NAME",
                                       description: "Name of the repo of the app",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       env_name: "GITHUB_TOKEN",
                                       description: "Github token to use to fetch releases and PR labels",
                                       optional: false,
                                       sensitive: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :current_version,
                                       description: "Checked-in version to bump from when there are no published GitHub releases yet",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :major_bump_labels,
                                       description: "PR labels that force a major version bump",
                                       optional: true,
                                       default_value: ["pr:force_major"],
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :minor_bump_labels,
                                       description: "PR labels that force a minor version bump",
                                       optional: true,
                                       default_value: ["pr:breaking", "pr:feat", "pr:force_minor"],
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :patch_bump_labels,
                                       description: "PR labels that force a patch version bump",
                                       optional: true,
                                       default_value: ["pr:fix", "pr:dependencies", "pr:force_patch"],
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :changelog_ignore_label,
                                       description: "PR label that excludes a PR from version calculation",
                                       optional: true,
                                       default_value: "pr:changelog_ignore",
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
