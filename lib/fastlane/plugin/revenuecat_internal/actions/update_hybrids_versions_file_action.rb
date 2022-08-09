require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/update_hybrids_versions_file_helper'

module Fastlane
  module Actions
    class UpdateHybridsVersionsFileAction < Action
      def self.run(params)
        versions_file_path = params[:versions_file_path]
        new_sdk_version = params[:new_sdk_version]
        hybrid_common_version = params[:hybrid_common_version]

        UI.user_error!("VERSIONS.md file not found") unless File.exist?(versions_file_path)

        android_version = Helper::UpdateHybridsVersionsFileHelper.get_android_version_for_hybrid_common_version(hybrid_common_version)
        UI.message("Obtained android version #{android_version} for PHC version #{hybrid_common_version}")

        ios_version = Helper::UpdateHybridsVersionsFileHelper.get_ios_version_for_hybrid_common_version(hybrid_common_version)
        UI.message("Obtained ios version #{ios_version} for PHC version #{hybrid_common_version}")

        File.open(versions_file_path, 'r+') do |file|
          lines = file.each_line.to_a
          lines.insert(2, "| #{new_sdk_version} | #{ios_version} | #{android_version} | #{hybrid_common_version} |\n")
          file.rewind
          file.write(lines.join)
        end
      end

      def self.description
        "Updates the VERSIONS.md file from the hybrid repos with the given version number and hybrid common version number"
      end

      def self.authors
        ["Toni Rico"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :versions_file_path,
                                       description: "Path to the VERSIONS.md file",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :new_sdk_version,
                                       description: "New version of the SDK to add to the VERSIONS.md file",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :hybrid_common_version,
                                       description: "Version of the hybrid common sdk to add to the VERSIONS.md file",
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
