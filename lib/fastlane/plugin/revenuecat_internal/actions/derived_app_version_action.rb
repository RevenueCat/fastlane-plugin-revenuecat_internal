require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/app_release_train_helper'

module Fastlane
  module Actions
    class DerivedAppVersionAction < Action
      def self.run(params)
        Helper::AppReleaseTrainHelper.derived_version(
          params[:checked_in_version],
          params[:main_branch],
          params[:repo_name],
          params[:github_token],
          major_bump_labels: params[:major_bump_labels],
          minor_bump_labels: params[:minor_bump_labels],
          patch_bump_labels: params[:patch_bump_labels],
          changelog_ignore_label: params[:changelog_ignore_label]
        )
      end

      def self.description
        "Derives the app version to build: on the main branch, the next release version from PR labels (falling back to a patch bump of the released baseline on failure or non-monotonic results); off main, the checked-in version."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.return_value
        "The version string to stamp on the build"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :checked_in_version,
                                       description: "Version currently checked in to the repo (e.g. MARKETING_VERSION or versionName)",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :main_branch,
                                       description: "Name of the trunk branch releases are derived on",
                                       optional: true,
                                       default_value: "main",
                                       type: String),
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
