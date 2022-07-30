require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class ReplaceTextInFilesAction < Action
      def self.run(params)
        previous_text = params[:previous_text]
        new_text = params[:new_text]
        paths_of_files_to_update = params[:paths_of_files_to_update]

        paths_of_files_to_update.each do |path|
          Helper::RevenuecatInternalHelper.replace_in(
            previous_text,
            new_text,
            path
          )
        end
      end

      def self.description
        "Replaces all occurences of previous text with new text in the given list of files"
      end

      def self.authors
        ["Toni Rico"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :previous_text,
                                       description: "Previous text to replace",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :new_text,
                                       description: "New text to replace",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :paths_of_files_to_update,
                                       description: "List of paths of files where we will perform the replace",
                                       optional: false,
                                       type: Array)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
