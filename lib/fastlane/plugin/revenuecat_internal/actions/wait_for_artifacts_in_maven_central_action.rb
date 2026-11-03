require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/maven_central_helper'

module Fastlane
  module Actions
    class WaitForArtifactsInMavenCentralAction < Action
      DEFAULT_TIMEOUT_SECONDS = 3600
      DEFAULT_POLL_INTERVAL_SECONDS = 60

      def self.run(params)
        artifact_ids = params[:artifact_ids]
        UI.user_error!('No artifacts provided. Please provide at least one artifact ID to wait for') if artifact_ids.empty?

        UI.message("Waiting for #{artifact_ids.join(', ')} #{params[:version]} on Maven Central")

        Helper::MavenCentralHelper.wait_for_artifacts(
          params[:group_id],
          artifact_ids,
          params[:version],
          params[:timeout],
          params[:poll_interval],
          params[:soft_fail]
        )
      end

      def self.description
        "Waits until the given artifact versions can be resolved from Maven Central"
      end

      def self.details
        [
          "A release published to the Central Portal isn't immediately resolvable from repo1.maven.org,",
          'so Gradle fails with "Could not find <artifact>" until it syncs.',
          "Gate anything that consumes a fresh release on this action."
        ].join(' ')
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
                                       description: "Array of artifact IDs to wait for (e.g., ['purchases', 'purchases-ui'])",
                                       optional: false,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "Version to wait for (e.g., '7.0.0')",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :timeout,
                                       description: "How many seconds to wait before giving up",
                                       optional: true,
                                       default_value: DEFAULT_TIMEOUT_SECONDS,
                                       type: Integer),
          FastlaneCore::ConfigItem.new(key: :poll_interval,
                                       description: "How many seconds to wait between checks",
                                       optional: true,
                                       default_value: DEFAULT_POLL_INTERVAL_SECONDS,
                                       type: Integer),
          FastlaneCore::ConfigItem.new(key: :soft_fail,
                                       description: "Warn and continue instead of failing when the timeout is reached",
                                       optional: true,
                                       default_value: false,
                                       type: Boolean)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
