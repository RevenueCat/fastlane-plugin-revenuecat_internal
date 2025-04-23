require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class CommitAllChangesAction < Action
      def self.run(params)
        commit_message = params[:commit_message]

        Helper::RevenuecatInternalHelper.commit_all_changes(commit_message)
      end

      def self.description
        "Commits all changes in the local repository to the current branch. This includes untracked and deleted files."
      end

      def self.authors
        ["Jay Shortway"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :commit_message,
                                       description: "Commit message",
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
