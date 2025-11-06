require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class PingHeartbeatMonitorAction < Action
      def self.run(params)
        if ENV["CI"] != "true"
          UI.message("Not running in CI environment, skipping heartbeat monitor ping.")
          return
        end
        unless ENV["CIRCLE_PULL_REQUEST"].to_s.empty?
          UI.message("Running in pull request context, skipping heartbeat monitor ping.")
          return
        end

        url = params[:url] || ENV.fetch("HEARTBEAT_MONITOR_URL", nil) || UI.user_error!("No url parameter nor HEARTBEAT_MONITOR_URL environment variable provided")

        Actions.sh("curl -m 5 --retry 3 #{url}")
      end

      def self.description
        "Pings a heartbeat monitor URL to signal job completion"
      end

      def self.authors
        ["Jay Shortway"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :url,
                                       description: "URL to ping for heartbeat monitoring. If not provided, will use HEARTBEAT_MONITOR_URL environment variable",
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
