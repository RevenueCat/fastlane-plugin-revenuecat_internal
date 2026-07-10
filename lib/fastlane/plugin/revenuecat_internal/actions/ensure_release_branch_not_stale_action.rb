require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/app_release_train_helper'

module Fastlane
  module Actions
    class EnsureReleaseBranchNotStaleAction < Action
      def self.run(params)
        Helper::AppReleaseTrainHelper.ensure_release_branch_not_stale!(params[:release_branch], params[:cut_from_sha])
      end

      def self.description
        "Fails if an existing release branch does not contain the commit the release should be cut from, or if it contains merge commits (which move the fork point)."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :release_branch,
                                       description: "Name of the release branch, used in error messages",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :cut_from_sha,
                                       description: "SHA of the commit the release should be cut from",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
