require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'
require_relative '../helper/versioning_helper'

module Fastlane
  module Actions
    class GitCloneAndPushAction < Action
      def self.run(params)
        source_repo = params[:source_repo]
        destination_repo = params[:destination_repo]

        Helper::RevenuecatInternalHelper.git_clone_source_to_dest(source_repo, destination_repo)
      end

      def self.description
        "Makes a lightweight clone containing only on the main branch's history."
      end

      def self.authors
        ["James Borthwick"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :source_repo,
                                       description: "The source repository URL",
                                       is_string: true),
          FastlaneCore::ConfigItem.new(key: :destination_repo,
                                       description: "The destination repository URL",
                                       is_string: true)
        ]
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end
    end
  end
end
