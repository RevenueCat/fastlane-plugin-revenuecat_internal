require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'net/http'
require 'uri'
require 'json'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class SlackBackendIntegrationTestResultsAction < Action
      ON_CALL_SDK_MENTION = "<!subteam^S0939BTV0SY|oncall-sdk>"

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
        message_binary_solo_on_failure = params[:message_binary_solo_on_failure] == true

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

        failure_message = "#{ON_CALL_SDK_MENTION} #{platform} backend integration tests failed."

        message_feed =
          if success
            "#{platform} backend integration tests finished successfully."
          else
            failure_message
          end

        detail_fields = [
          { title: "SDK", value: repo_name },
          { title: "SDK version", value: major_version },
          { title: "Git branch", value: Actions.sh("git rev-parse --abbrev-ref HEAD").strip },
          { title: "Environment", value: environment },
          { title: "Test suite", value: ENV.fetch("CIRCLE_JOB", nil) }
        ]
        build_url = ENV.fetch("CIRCLE_BUILD_URL", nil)

        if !success && message_binary_solo_on_failure
          slack_url_binary_solo = ENV.fetch("SLACK_URL_BINARY_SOLO") { UI.user_error!("Missing required SLACK_URL_BINARY_SOLO environment variable. Make sure to provide the slack-secrets CircleCI context.") }

          post_to_slack(slack_url_binary_solo, build_payload(failure_message, success, detail_fields, build_url))
        end

        post_to_slack(slack_url_feed, build_payload(message_feed, success, detail_fields, build_url))
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.build_payload(message, success, fields, build_url)
        detail_blocks = [
          {
            type: "section",
            fields: fields.map do |field|
              { type: "mrkdwn", text: "*#{field[:title]}*\n#{field[:value]}" }
            end
          }
        ]

        unless build_url.to_s.empty?
          detail_blocks << {
            type: "actions",
            elements: [
              {
                type: "button",
                text: { type: "plain_text", text: "View CircleCI logs" },
                url: build_url
              }
            ]
          }
        end

        {
          text: message,
          blocks: [
            {
              type: "section",
              text: { type: "mrkdwn", text: message }
            }
          ],
          attachments: [
            {
              color: success ? "good" : "danger",
              blocks: detail_blocks
            }
          ]
        }
      end

      def self.post_to_slack(slack_url, payload)
        uri = URI.parse(slack_url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"

        request = Net::HTTP::Post.new(uri.request_uri, "Content-Type" => "application/json")
        request.body = payload.to_json

        response = http.request(request)

        unless response.kind_of?(Net::HTTPSuccess)
          UI.user_error!("Error sending Slack notification: #{response.code} #{response.body}")
        end

        UI.success("Successfully sent Slack notification")
      end

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
                                       description: "Whether to also notify binary-solo when tests fail. On-call is always pinged in the backend integration tests feed channel on failure",
                                       optional: true,
                                       default_value: false,
                                       is_string: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
