require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require 'fileutils'
require 'securerandom'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class RunSdkUpdateMaestroTestAction < Action
      PLATFORMS = %w[ios android].freeze
      STEP_KEYS = %i[app_path sdk_version flow].freeze

      def self.run(params)
        fastlane_dir = FastlaneCore::FastlaneFolder.path
        platform = params[:platform]
        app_id = params[:app_id]
        output_dir = File.expand_path(params[:output_dir], fastlane_dir)
        max_attempts = params[:max_attempts]
        steps = resolve_steps(params[:steps], fastlane_dir)
        commit = Actions.sh("git", "rev-parse", "--short", "HEAD", log: false).strip

        FileUtils.rm_rf(output_dir)
        (1..max_attempts).each do |attempt|
          attempt_dir = "#{output_dir}/attempt_#{attempt}"
          screenshots_dir = "#{attempt_dir}/reference_screenshots"
          FileUtils.mkdir_p(screenshots_dir)
          # Unique per attempt, so that retries don't start with a user that already purchased.
          app_user_id = "sdk-update-test-#{commit}-#{attempt}-#{SecureRandom.hex(4)}"

          begin
            UI.message("SDK update test, attempt #{attempt}/#{max_attempts}")
            # Cleaning up before rather than after, so that each attempt starts from a clean state regardless of how
            # previous runs ended, and the final state is kept for debugging.
            reset_device_state(platform, app_id)

            steps.each_with_index do |step, index|
              UI.message("Installing app built against SDK #{step[:sdk_version]}: #{step[:app_path]}")
              background_app(platform)
              sleep(3) if index.positive?
              install_app(platform, step[:app_path])
              Actions.sh(
                "maestro", "test",
                "--format", "junit",
                "--output", "#{attempt_dir}/#{step[:name]}/report.xml",
                "--test-output-dir", "#{attempt_dir}/#{step[:name]}",
                "-e", "SCREENSHOTS_DIR=#{screenshots_dir}",
                "-e", "EXPECTED_SDK_VERSION=#{step[:sdk_version]}",
                "-e", "APP_USER_ID=#{app_user_id}",
                step[:flow]
              )
            end

            UI.success("✅ SDK update test passed on attempt #{attempt}")
            break
          rescue StandardError => e
            UI.error("SDK update test attempt #{attempt} failed: #{e.message}")
            raise e if attempt >= max_attempts
          ensure
            # Only the reports of the last attempt are kept, so that retried failures don't show up as failed tests.
            copy_junit_reports(attempt_dir, "#{output_dir}/junit")
          end
        end

        true
      end

      def self.resolve_steps(steps, fastlane_dir)
        steps.each_with_index.map do |step, index|
          flow = File.expand_path(step[:flow], fastlane_dir)
          app_path = File.expand_path(step[:app_path], fastlane_dir)
          UI.user_error!("Flow not found: #{flow}") unless File.exist?(flow)
          UI.user_error!("App not found: #{app_path}") unless File.exist?(app_path)

          {
            name: "#{index + 1}_#{File.basename(flow, '.*')}",
            app_path: app_path,
            sdk_version: step[:sdk_version],
            flow: flow
          }
        end
      end

      def self.reset_device_state(platform, app_id)
        case platform
        when "ios"
          Actions.sh("xcrun", "simctl", "uninstall", "booted", app_id)
          # Keychain items survive uninstalling apps on simulators.
          Actions.sh("xcrun", "simctl", "keychain", "booted", "reset")
        when "android"
          # Fails when the app isn't installed, which is fine.
          Actions.sh("adb", "uninstall", app_id, error_callback: ->(_) {})
        end
      end

      # Installs over any existing installation keeping its data, like an app update.
      def self.install_app(platform, app_path)
        case platform
        when "ios"
          Actions.sh("xcrun", "simctl", "install", "booted", app_path)
        when "android"
          Actions.sh("adb", "install", "-r", app_path)
        end
      end

      def self.background_app(platform)
        case platform
        when "ios"
          Actions.sh("xcrun", "simctl", "launch", "booted", "com.apple.springboard")
        when "android"
          Actions.sh("adb", "shell", "input", "keyevent", "KEYCODE_HOME")
        end
      end

      def self.copy_junit_reports(attempt_dir, junit_dir)
        FileUtils.rm_rf(junit_dir)
        Dir.glob("#{attempt_dir}/*/report.xml").each do |report|
          FileUtils.mkdir_p(junit_dir)
          FileUtils.cp(report, "#{junit_dir}/#{File.basename(File.dirname(report))}.xml")
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Runs a Maestro SDK update test: installs apps built against different SDK versions over each other, like app updates, running a flow after each install"
      end

      def self.details
        "Each step sends the app to the Home screen, installs its app over the previous one keeping its data " \
          "like an app update, and runs its flow. " \
          "The first step starts from a clean state: the app is uninstalled and, on iOS, the simulator's keychain is reset. " \
          "Only later steps wait three seconds after going Home for the background transition. " \
          "The whole sequence is retried from a clean state on failure. To run several test cases, call this action once " \
          "per test case. " \
          "Flows receive the `SCREENSHOTS_DIR` (shared by all steps of an attempt, to compare screenshots across updates), " \
          "`EXPECTED_SDK_VERSION` (SDK version of the step's app) and `APP_USER_ID` (unique per attempt) environment variables. " \
          "The JUnit reports of the last attempt are copied to `<output_dir>/junit`, named `<step number>_<flow name>.xml`. " \
          "On Android, all APKs must be signed with the same key for the updates to install, e.g. by building them " \
          "on the same machine with its default debug keystore."
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :platform,
                                       description: "Platform of the apps: #{PLATFORMS.join(' or ')}",
                                       type: String,
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("platform must be one of: #{PLATFORMS.join(', ')}") unless PLATFORMS.include?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :app_id,
                                       description: "Bundle identifier (iOS) or package name (Android) of the apps",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :steps,
                                       description: "Steps of the update sequence, in order. Each one is a Hash with the " \
                                                    "`app_path` (.app or .apk) to install, the `sdk_version` it was built against " \
                                                    "and the Maestro `flow` file to run",
                                       type: Array,
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("steps must contain at least 2 steps") if value.size < 2
                                         value.each do |step|
                                           missing_keys = step.kind_of?(Hash) ? STEP_KEYS.reject { |key| step[key] } : STEP_KEYS
                                           UI.user_error!("Each step needs #{STEP_KEYS.join(', ')}. Invalid step: #{step}") unless missing_keys.empty?
                                         end
                                       end),
          FastlaneCore::ConfigItem.new(key: :output_dir,
                                       description: "Directory to store the test output and JUnit reports in. Cleared before running",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :max_attempts,
                                       description: "Maximum number of attempts of the whole sequence",
                                       type: Integer,
                                       optional: false,
                                       verify_block: proc do |value|
                                         UI.user_error!("max_attempts must be greater than 0") unless value.positive?
                                       end)
        ]
      end

      def self.return_value
        "Returns true if the test passed (possibly after retries), raises on final failure"
      end

      def self.authors
        ["Antonio Pallares"]
      end

      def self.is_supported?(platform)
        true
      end

      def self.example_code
        [
          'run_sdk_update_maestro_test(
            platform: "ios",
            app_id: "com.revenuecat.SDKUpdateTester",
            steps: [
              { app_path: "build/release/SDKUpdateTester.app", sdk_version: "5.92.0", flow: "maestro/anonymous_user/before_update.yaml" },
              { app_path: "build/local/SDKUpdateTester.app", sdk_version: "5.93.0-SNAPSHOT", flow: "maestro/anonymous_user/after_update.yaml" }
            ],
            output_dir: "test_output/sdk_update_tests/anonymous_user",
            max_attempts: 3
          )'
        ]
      end

      def self.category
        :testing
      end
    end
  end
end
