require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/app_release_train_helper'

module Fastlane
  module Actions
    class ReleaseCandidateBuildNumberAction < Action
      def self.run(params)
        Helper::AppReleaseTrainHelper.release_candidate_build_number(params[:version], params[:main_branch])
      end

      def self.description
        "Returns the build number of the candidate build for a release branch: the builds/<version>-<build> tag pointing at the merge-base of HEAD and origin/<main_branch>."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.return_value
        "The candidate build number as an Integer"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Version the release is being cut as",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :main_branch,
                                       description: "Name of the trunk branch the release was cut from",
                                       optional: true,
                                       default_value: "main",
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
