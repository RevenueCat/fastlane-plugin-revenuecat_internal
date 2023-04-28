require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class ReplaceVersionNumberAction < Action
      def self.run(params)
        previous_version_number = params[:current_version]
        new_version_number = params[:new_version_number]
        files_to_update = params[:files_to_update]
        files_to_update_without_prerelease_modifiers = params[:files_to_update_without_prerelease_modifiers]
        Helper::RevenuecatInternalHelper.replace_version_number(previous_version_number,
                                                                new_version_number,
                                                                files_to_update,
                                                                files_to_update_without_prerelease_modifiers)
      end

      def self.description
        "Replaces version number in list of given files"
      end

      def self.authors
        ["Toni Rico"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :current_version,
                                       description: "Current version of the sdk",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :new_version_number,
                                       description: "New version of the sdk",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :files_to_update,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_VERSION",
                                       description: 'Hash of files that contain the version number and need to have it' \
                                                    'updated to the patterns that contains the version in the file.' \
                                                    'Mark the version in the pattern using {x}.' \
                                                    'For example: { "./pubspec.yaml" => ["version: {x}"] }',
                                       optional: false,
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :files_to_update_without_prerelease_modifiers,
                                       env_name: "RC_INTERNAL_FILES_TO_UPDATE_VERSION_WITHOUT_PRERELEASE_MODIFIERS",
                                       description: 'Hash of files that contain the version number without pre-release' \
                                                    'modifier and need to have it updated, to the patterns that' \
                                                    'contains the version in the file.' \
                                                    'Mark the version in the pattern using {x}.' \
                                                    'For example: { "./pubspec.yaml" => ["version: {x}"] }',
                                       optional: true,
                                       default_value: {},
                                       type: Hash)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
