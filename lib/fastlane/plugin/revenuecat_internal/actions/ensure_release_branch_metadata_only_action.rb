require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/app_release_train_helper'

module Fastlane
  module Actions
    class EnsureReleaseBranchMetadataOnlyAction < Action
      def self.run(params)
        if params[:version_file] && params[:version_line_pattern].to_s.empty?
          UI.user_error!("version_line_pattern is required when version_file is provided.")
        end

        Helper::AppReleaseTrainHelper.ensure_release_branch_is_metadata_only!(
          params[:main_branch],
          params[:allowed_path_prefixes],
          params[:version_file],
          params[:version_line_pattern]
        )
      end

      def self.description
        "Fails unless the release branch only changes release metadata since its fork point from main: no merge commits, only allowed path prefixes (plus the version file, whose changed lines must all match the version line pattern)."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :main_branch,
                                       description: "Name of the trunk branch the release was cut from",
                                       optional: true,
                                       default_value: "main",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :allowed_path_prefixes,
                                       description: "Path prefixes the release branch is allowed to change, e.g. [\"fastlane/metadata/\"]",
                                       optional: false,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :version_file,
                                       description: "Project file whose only allowed edits are version lines, e.g. \"RevenueCat.xcodeproj/project.pbxproj\"",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :version_line_pattern,
                                       description: "Regex (as a string) every changed line in version_file must match, e.g. \"MARKETING_VERSION\"",
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
