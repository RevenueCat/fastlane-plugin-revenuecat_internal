require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/app_release_train_helper'

module Fastlane
  module Actions
    class EnsureCandidateVersionMatchesAction < Action
      def self.run(params)
        Helper::AppReleaseTrainHelper.ensure_candidate_version_matches!(params[:sha], params[:version])
      end

      def self.description
        "Fails unless a builds/<version>-<build> tag at the given commit matches the computed release version, catching derivations that drifted since the candidate uploaded (e.g. a label edited after the upload)."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :sha,
                                       description: "SHA of the candidate commit",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Version the cut computed",
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
