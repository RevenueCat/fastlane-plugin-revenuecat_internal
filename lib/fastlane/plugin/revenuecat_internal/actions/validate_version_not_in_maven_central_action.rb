require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/maven_central_helper'

module Fastlane
  module Actions
    class ValidateVersionNotInMavenCentralAction < Action
      def self.run(params)
        group_id = params[:group_id]
        artifact_ids = params[:artifact_ids]
        version = params[:version]
        auth_token = params[:auth_token] || ENV.fetch("FETCH_PUBLICATIONS_USER_TOKEN_MAVEN_CENTRAL", nil)

        UI.message("Checking if version #{version} already exists in Maven Central...")

        if artifact_ids.empty?
          UI.user_error!("No artifacts provided. Please provide at least one artifact ID to check")
        else
          UI.message("Found #{artifact_ids.length} artifacts to check: #{artifact_ids.join(', ')}")
          Helper::MavenCentralHelper.check_version_not_published(version, group_id, artifact_ids, auth_token)
          UI.success("Version #{version} does not exist in Maven Central. Proceeding with deployment.")
        end
      end

      def self.description
        "Checks if a specific version of Maven artifacts already exists in Maven Central before deployment"
      end

      def self.authors
        ["RevenueCat"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :group_id,
                                       description: "Maven group ID (e.g., 'com.revenuecat.purchases')",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :artifact_ids,
                                       description: "Array of artifact IDs to check (e.g., ['purchases', 'purchases-ui'])",
                                       optional: false,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Version to check (e.g., '7.0.0')",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :auth_token,
                                       description: "Authentication token for Maven Central API (defaults to FETCH_PUBLICATIONS_USER_TOKEN_MAVEN_CENTRAL env var)",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
