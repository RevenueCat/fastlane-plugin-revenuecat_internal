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

      SUCCESS_COLOR = "#36A64F"
      FAILURE_COLOR = "#D00000"

      CIRCLE_API_PAGE_SIZE = 100
      # The notifying jobs run once a day while main takes roughly four hundred builds a day, so the
      # previous run of one of them sits several pages back. Measured at position 457 on 2026-09-18.
      # Paging stops as soon as the job is found or the branch history runs out, so this is a ceiling
      # rather than a cost, and giving up early would silently mean "post every success".
      CIRCLE_API_MAX_PAGES = 12

      PREVIOUS_RUN_SUCCESS_STATUSES = %w[success fixed].freeze
      PREVIOUS_RUN_FAILURE_STATUSES = %w[failed timedout infrastructure_fail].freeze

      def self.run(params)
        return unless should_send_notification?

        environment = params[:environment]
        success = params[:success] || false
        message_binary_solo_on_failure = params[:message_binary_solo_on_failure] == true

        repo_name = ENV.fetch("CIRCLE_PROJECT_REPONAME", nil)
        major_version = resolve_version(params).split('.')[0]
        platform = resolve_platform(params, repo_name)

        git_branch = current_branch

        message_feed =
          if success
            success_message(params, platform, git_branch)
          else
            "#{ON_CALL_SDK_MENTION} #{platform} backend integration tests failed."
          end

        if message_feed.nil?
          UI.message("The previous run of this job on #{git_branch} did not fail, skipping Slack notification.")
          return
        end

        detail_fields = [
          { title: "SDK", value: repo_name },
          { title: "SDK version", value: major_version },
          { title: "Git branch", value: git_branch },
          { title: "Environment", value: environment },
          { title: "Test suite", value: ENV.fetch("CIRCLE_JOB", nil) }
        ]
        build_url = ENV.fetch("CIRCLE_BUILD_URL", nil)

        post_messages(
          success: success,
          notify_binary_solo_on_failure: message_binary_solo_on_failure,
          feed_message: message_feed,
          fields: detail_fields,
          build_url: build_url
        )
      end

      def self.post_messages(success:, notify_binary_solo_on_failure:, feed_message:, fields:, build_url:)
        if notify_binary_solo_on_failure && !success
          slack_url_binary_solo = ENV.fetch("SLACK_URL_BINARY_SOLO") { UI.user_error!("Missing required SLACK_URL_BINARY_SOLO environment variable. Make sure to provide the slack-secrets CircleCI context.") }

          post_to_slack(slack_url_binary_solo, build_payload(feed_message, success, fields, build_url))
        end

        slack_url_feed = ENV.fetch("SLACK_URL_BACKEND_INTEGRATION_TESTS") { UI.user_error!("Missing required SLACK_URL_BACKEND_INTEGRATION_TESTS environment variable. Make sure to provide the slack-secrets CircleCI context.") }

        post_to_slack(slack_url_feed, build_payload(feed_message, success, fields, build_url))
      end

      # Returns nil when a success is not worth announcing. A green run following a green run says
      # nothing new, so only failures and recoveries reach the channel.
      def self.current_branch
        circle_branch = ENV.fetch("CIRCLE_BRANCH", nil)
        return circle_branch unless circle_branch.to_s.empty?

        Actions.sh("git rev-parse --abbrev-ref HEAD").strip
      end

      def self.success_message(params, platform, branch)
        finished_successfully = "#{platform} backend integration tests finished successfully."
        return finished_successfully unless params[:notify_success_only_on_recovery]

        case previous_job_status(job: ENV.fetch("CIRCLE_JOB", nil), branch: branch, build_num: ENV.fetch("CIRCLE_BUILD_NUM", nil))
        when :failed then "#{platform} backend integration tests recovered."
        when :unknown then finished_successfully
        end
      end

      # CircleCI already keeps the history this needs, so recoveries do not require storing any state
      # of our own. Returns :failed, :success, :none when the branch has no earlier run of the job, or
      # :unknown when the history cannot be read far enough back to tell.
      def self.previous_job_status(job:, branch:, build_num:)
        return :unknown if job.to_s.empty? || branch.to_s.empty? || build_num.to_s.empty?

        build_num = build_num.to_i

        CIRCLE_API_MAX_PAGES.times do |page|
          builds = fetch_recent_builds(branch: branch, offset: page * CIRCLE_API_PAGE_SIZE)
          return :unknown if builds.nil?

          status = status_of_earlier_run(builds, job: job, build_num: build_num)
          return status unless status.nil?
          return :none if builds.size < CIRCLE_API_PAGE_SIZE
        end

        :unknown
      end

      # nil when this page of the history holds no conclusive earlier run of the job.
      def self.status_of_earlier_run(builds, job:, build_num:)
        earlier_runs = builds.select do |build|
          build.dig("workflows", "job_name") == job && build["build_num"].to_i < build_num
        end

        earlier_runs.each do |build|
          status = build["status"].to_s
          return :failed if PREVIOUS_RUN_FAILURE_STATUSES.include?(status)
          return :success if PREVIOUS_RUN_SUCCESS_STATUSES.include?(status)
          # Canceled and never-started runs carry no result, so keep looking further back.
        end

        nil
      end

      def self.fetch_recent_builds(branch:, offset:)
        url = recent_builds_url(branch: branch, offset: offset)
        return nil if url.nil?

        response = Net::HTTP.get_response(URI.parse(url))
        unless response.kind_of?(Net::HTTPSuccess)
          UI.important("Could not read the CircleCI build history: #{response.code}")
          return nil
        end

        builds = JSON.parse(response.body)
        builds.kind_of?(Array) ? builds : nil
      rescue StandardError => e
        UI.important("Could not read the CircleCI build history: #{e.message}")
        nil
      end

      def self.recent_builds_url(branch:, offset:)
        org = ENV.fetch("CIRCLE_PROJECT_USERNAME", nil)
        repo = ENV.fetch("CIRCLE_PROJECT_REPONAME", nil)
        return nil if org.to_s.empty? || repo.to_s.empty?

        escaped_branch = URI.encode_www_form_component(branch)
        "https://circleci.com/api/v1.1/project/github/#{org}/#{repo}/tree/#{escaped_branch}" \
          "?filter=completed&shallow=true&limit=#{CIRCLE_API_PAGE_SIZE}&offset=#{offset}"
      end

      def self.should_send_notification?
        if ENV["CI"] != "true"
          UI.message("Not running in CI environment, skipping slack notification.")
          return false
        end
        unless ENV["CIRCLE_PULL_REQUEST"].to_s.empty?
          UI.message("Running in pull request context, skipping slack notification.")
          return false
        end

        true
      end

      def self.resolve_version(params)
        version = params[:version] || begin
          File.readlines(File.expand_path('.version', Dir.pwd)).first&.strip
        rescue StandardError
          nil
        end

        version || UI.user_error!("Missing version parameter")
      end

      def self.resolve_platform(params, repo_name)
        params[:platform] || case repo_name
                             when "purchases-android" then "Android"
                             when "purchases-ios" then "iOS"
                             else UI.user_error!("Missing platform parameter")
                             end
      end

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
              color: success ? SUCCESS_COLOR : FAILURE_COLOR,
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
          FastlaneCore::ConfigItem.new(key: :notify_success_only_on_recovery,
                                       description: "Whether a success should only be announced when it follows a failure of the same job on the same branch",
                                       optional: true,
                                       default_value: false,
                                       is_string: false),
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
