require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/app_release_train_helper'

module Fastlane
  module Actions
    class CommitCountBuildNumberAction < Action
      def self.run(params)
        Helper::AppReleaseTrainHelper.commit_count_build_number
      end

      def self.description
        "Computes the build number as the commit count of HEAD (unshallowing the checkout first): monotonic, collision-free across concurrent merges, and derivable from any checkout."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.return_value
        "The build number as an Integer"
      end

      def self.available_options
        []
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
