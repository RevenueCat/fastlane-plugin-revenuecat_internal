require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/app_release_train_helper'

module Fastlane
  module Actions
    class FindReleaseCandidateCommitAction < Action
      def self.run(params)
        Helper::AppReleaseTrainHelper.find_candidate_commit(
          params[:repo_name],
          params[:github_token],
          skip_label: params[:skip_label],
          lookback: params[:lookback],
          allow_unbuilt: params[:allow_unbuilt]
        )
      end

      def self.description
        "Finds the newest first-parent commit with an uploaded candidate build (a builds/* tag). Untagged commits fail the walk unless their merged PR has the skip label, or allow_unbuilt is set (for repos that upload on a schedule rather than per merge)."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.return_value
        "The SHA of the newest commit with a candidate build"
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
                                       description: "Github token to use to fetch PR labels",
                                       optional: false,
                                       sensitive: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :skip_label,
                                       description: "PR label that marks merges which intentionally skip the candidate upload",
                                       optional: true,
                                       default_value: "upload:skip",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :lookback,
                                       description: "How many first-parent commits to walk before giving up",
                                       optional: true,
                                       default_value: 30,
                                       type: Integer),
          FastlaneCore::ConfigItem.new(key: :allow_unbuilt,
                                       description: "Treat untagged commits as normal (uploads happen on a schedule, not per merge) instead of failing without the skip label",
                                       optional: true,
                                       default_value: false,
                                       type: Boolean)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
