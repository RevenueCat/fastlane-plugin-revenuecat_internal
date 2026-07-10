require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/app_release_train_helper'

module Fastlane
  module Actions
    class TagUploadedBuildAction < Action
      def self.run(params)
        Helper::AppReleaseTrainHelper.tag_uploaded_build(params[:version], params[:build_number])
      end

      def self.description
        "Tags HEAD as builds/<version>-<build> and pushes the tag. Best-effort: failures are logged but never raised, so tagging cannot fail an upload that already happened."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Version the build was uploaded as",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :build_number,
                                       description: "Build number the build was uploaded as",
                                       optional: false,
                                       is_string: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
