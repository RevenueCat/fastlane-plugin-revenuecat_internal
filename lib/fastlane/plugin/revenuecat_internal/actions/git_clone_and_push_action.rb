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
        "Makes a lightweight clone containing only on the main branch's history. Includes Git tags."
      end

      def self.authors
        ["James Borthwick"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :source_repo,
                                       description: "The source repository URL",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :destination_repo,
                                       description: "The destination repository URL",
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
