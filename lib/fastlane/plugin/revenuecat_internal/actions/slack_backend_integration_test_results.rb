require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class SlackBackendIntegrationTestResultsAction < Action
      # rubocop:disable Metrics/PerceivedComplexity
      def self.run(params)
        if ENV["CI"] != "true"
          UI.message("Not running in CI environment, skipping slack notification.")
          return
        end
        unless ENV["CIRCLE_PULL_REQUEST"].to_s.empty?
          UI.message("Running in pull request context, skipping slack notification.")
          return
        end

        environment = params[:environment]
        success = params[:success] || false
        message_binary_solo_on_failure = params[:message_binary_solo_on_failure] != false

        version = params[:version] || begin
          File.readlines(File.expand_path('.version', Dir.pwd)).first&.strip
        rescue StandardError
          nil
        end || UI.user_error!("Missing version parameter")

        major_version = version.split('.')[0]
        repo_name = ENV.fetch("CIRCLE_PROJECT_REPONAME", nil)
        platform = params[:platform] || case repo_name
                                        when "purchases-android" then "Android"
                                        when "purchases-ios" then "iOS"
                                        else UI.user_error!("Missing platform parameter")
                                        end

        slack_url_feed = ENV.fetch("SLACK_URL_BACKEND_INTEGRATION_TESTS") { UI.user_error!("Missing required SLACK_URL_BACKEND_INTEGRATION_TESTS environment variable. Make sure to provide the slack-secrets CircleCI context.") }
        slack_url_binary_solo = ENV.fetch("SLACK_URL_BINARY_SOLO") { UI.user_error!("Missing required SLACK_URL_BINARY_SOLO environment variable. Make sure to provide the slack-secrets CircleCI context.") }

        message_feed =
          if success
            "#{platform} backend integration tests finished successfully."
          else
            "#{platform} backend integration tests failed. On-call is pinged in <#CL407G2QL|binary-solo>."
          end

        message_binary_solo =
          unless success
            "<!subteam^S0939BTV0SY|oncall-sdk> <!subteam^S061NM11SNN|oncall-infra> <!subteam^S0621D5SHG9|oncall-product> #{platform} backend integration tests failed."
          end

        slack_options = {
          success: success,
          default_payloads: [],
          attachment_properties: {
            actions: [
              {
                type: "button",
                text: "View CircleCI logs",
                url: ENV.fetch("CIRCLE_BUILD_URL", nil)
              }
            ],
            fields: [
              {
                title: "SDK",
                value: repo_name,
                short: true
              },
              {
                title: "SDK version",
                value: major_version,
                short: true
              },
              {
                title: "Git branch",
                value: Actions.sh("git rev-parse --abbrev-ref HEAD"),
                short: true
              },
              {
                title: "Environment",
                value: environment,
                short: true
              },
              {
                title: "Test suite",
                value: ENV.fetch("CIRCLE_JOB", nil),
                short: false
              }
            ]
          }
        }

        if message_binary_solo && message_binary_solo_on_failure
          other_action.slack(
            slack_options.merge(
              message: message_binary_solo,
              slack_url: slack_url_binary_solo
            )
          )
        end

        other_action.slack(
          slack_options.merge(
            message: message_feed,
            slack_url: slack_url_feed
          )
        )
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.description
        "Sends backend integration test results to Slack channels with detailed CircleCI context"
      end

      def self.authors
        ["Jay Shortway"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :environment,
                                       description: "The environment where tests were run (e.g., production, loadshedder, etc.)",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :success,
                                       description: "Whether the tests passed successfully. Will default to false if not provided",
                                       optional: true,
                                       default_value: false,
                                       is_string: false),
          FastlaneCore::ConfigItem.new(key: :version,
                                       description: "SDK version being tested. If not provided, will read from .version file",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :platform,
                                       description: "Platform being tested (Android or iOS). If not provided, will be inferred from CIRCLE_PROJECT_REPONAME",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :message_binary_solo_on_failure,
                                       description: "Whether to ping the binary-solo / on-call group when tests fail",
                                       optional: true,
                                       default_value: true,
                                       is_string: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
