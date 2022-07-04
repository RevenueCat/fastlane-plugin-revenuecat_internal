require 'fastlane/action'
require_relative '../helper/revenuecat_helper'

module Fastlane
  module Actions
    class ReplaceVersionNumberAction < Action
      def self.run(params)
        previous_version_number = params[:current_version]
        new_version_number = params[:new_version]
        files_to_update = params[:files_to_update]
        UI.user_error!("missing current version param") unless previous_version_number
        UI.user_error!("missing new version param") unless new_version_number
        UI.user_error!("missing files to update param") unless files_to_update
        previous_version_number_without_prerelease_modifiers = previous_version_number.split("-")[0]
        new_version_number_without_prerelease_modifiers = new_version_number.split("-")[0]

        files_to_update.each do |file_to_update|
          Helper::RevenuecatHelper.replace_in(previous_version_number, new_version_number, file_to_update)
          Helper::RevenuecatHelper.replace_in(previous_version_number_without_prerelease_modifiers, new_version_number_without_prerelease_modifiers, file_to_update)
        end
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
          FastlaneCore::ConfigItem.new(key: :new_version,
                               description: "New version of the sdk",
                                  optional: false,
                                      type: String),
          FastlaneCore::ConfigItem.new(key: :files_to_update,
                                  env_name: "FILES_TO_UPDATE_VERSION",
                               description: "Files that contain the version number and need to have it updated",
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
