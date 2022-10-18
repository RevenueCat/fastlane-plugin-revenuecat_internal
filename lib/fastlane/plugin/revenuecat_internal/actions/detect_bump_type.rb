require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/versioning_helper'

module Fastlane
  module Actions
    class DetectBumpTypeAction < Action
      def self.run(params)
        previous_version_number = params[:current_version]
        new_version_number = params[:new_version_number]
        Helper::VersioningHelper.detect_bump_type(previous_version_number, new_version_number)
      end

      def self.description
        "Compares two versions and returns the type of bump between them (major, minor or patch)"
      end

      def self.authors
        ["Cesar de la Vega"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :current_version,
                                       description: "Previous version before bump",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :new_version_number,
                                       description: "New version after bump",
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
