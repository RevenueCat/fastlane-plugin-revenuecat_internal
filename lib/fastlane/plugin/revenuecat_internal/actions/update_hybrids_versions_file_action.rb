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

        billing_client_version = Helper::UpdateHybridsVersionsFileHelper.get_android_billing_client_version(android_version)
        UI.message("Obtained android billing client version #{billing_client_version} for PHC version #{hybrid_common_version}")

        File.open(versions_file_path, 'r+') do |file|
          lines = file.each_line.to_a
          if lines[0].split('|').length <= 6
            lines[0] = "#{lines[0].strip} Android Billing Client version |\n"
            lines[1] = "#{lines[1].strip}--------------------------------|\n"
            lines.each_with_index do |line, index|
              if index > 1
                lines[index] = "#{line.strip} |\n"
              end
            end
          end
          lines.insert(2, "| #{new_sdk_version} " \
                          "| [#{ios_version}](https://github.com/RevenueCat/purchases-ios/releases/tag/#{ios_version}) " \
                          "| [#{android_version}](https://github.com/RevenueCat/purchases-android/releases/tag/#{android_version}) " \
                          "| [#{hybrid_common_version}](https://github.com/RevenueCat/purchases-hybrid-common/releases/tag/#{hybrid_common_version}) " \
                          "| [#{billing_client_version}](https://developer.android.com/google/play/billing/release-notes) |\n")
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
