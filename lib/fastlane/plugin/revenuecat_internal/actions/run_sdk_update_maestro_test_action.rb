require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require 'fileutils'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class RunSdkUpdateMaestroTestAction < Action
      BEFORE_UPDATE_FLOW = "1_before_update".freeze
      AFTER_UPDATE_FLOW = "2_after_update".freeze
      PLATFORMS = %w[ios android].freeze

      def self.run(params)
        fastlane_dir = FastlaneCore::FastlaneFolder.path
        platform = params[:platform]
        app_id = params[:app_id]
        flows_dir = File.expand_path(params[:flows_dir], fastlane_dir)
        output_dir = File.expand_path(params[:output_dir], fastlane_dir)
        max_attempts = params[:max_attempts]
        apps = [
          { flow: BEFORE_UPDATE_FLOW, path: File.expand_path(params[:release_app_path], fastlane_dir), sdk_version: params[:release_sdk_version] },
          { flow: AFTER_UPDATE_FLOW, path: File.expand_path(params[:local_app_path], fastlane_dir), sdk_version: params[:local_sdk_version] }
        ]

        apps.each do |app|
          flow_path = "#{flows_dir}/#{app[:flow]}.yaml"
          UI.user_error!("Flow not found: #{flow_path}") unless File.exist?(flow_path)
          UI.user_error!("App not found: #{app[:path]}") unless File.exist?(app[:path])
        end
        commit = Actions.sh("git", "rev-parse", "--short", "HEAD", log: false).strip

        FileUtils.rm_rf(output_dir)
        (1..max_attempts).each do |attempt|
          attempt_dir = "#{output_dir}/attempt_#{attempt}"
          screenshots_dir = "#{attempt_dir}/reference_screenshots"
          FileUtils.mkdir_p(screenshots_dir)
          # Unique per attempt, so that retries don't start with a user that already purchased.
          app_user_id = "sdk-update-test-#{commit}-#{Time.now.to_i}-#{attempt}"

          begin
            UI.message("SDK update test '#{File.basename(flows_dir)}', attempt #{attempt}/#{max_attempts}")
            uninstall_app(platform, app_id)

            apps.each do |app|
              UI.message("Installing app built against SDK #{app[:sdk_version]}: #{app[:path]}")
              install_app(platform, app[:path])
              Actions.sh(
                "maestro", "test",
                "--format", "junit",
                "--output", "#{attempt_dir}/#{app[:flow]}/report.xml",
                "--test-output-dir", "#{attempt_dir}/#{app[:flow]}",
                "-e", "SCREENSHOTS_DIR=#{screenshots_dir}",
                "-e", "EXPECTED_SDK_VERSION=#{app[:sdk_version]}",
                "-e", "APP_USER_ID=#{app_user_id}",
                "#{flows_dir}/#{app[:flow]}.yaml"
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

      def self.uninstall_app(platform, app_id)
        case platform
        when "ios"
          Actions.sh("xcrun", "simctl", "uninstall", "booted", app_id)
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
        "Runs a Maestro SDK update test: runs a flow on an app built against a released SDK, updates the app to one built against the local SDK, and runs another flow"
      end

      def self.details
        "Installs the release app on a clean booted simulator/emulator and runs `1_before_update.yaml` from `flows_dir`. " \
          "Then installs the local app over it, keeping its data like an app update, and runs `2_after_update.yaml`. " \
          "The whole sequence is retried from a clean install on failure. " \
          "Flows receive the `SCREENSHOTS_DIR` (shared by both flows of an attempt, to compare screenshots across the update), " \
          "`EXPECTED_SDK_VERSION` (SDK version of the installed app) and `APP_USER_ID` (unique per attempt) environment variables. " \
          "The JUnit reports of the last attempt are copied to `<output_dir>/junit`. " \
          "On Android, both APKs must be signed with the same key for the update to install, e.g. by building them " \
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
          FastlaneCore::ConfigItem.new(key: :release_app_path,
                                       description: "Path to the app (.app or .apk) built against the released SDK",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :release_sdk_version,
                                       description: "SDK version the release app was built against",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :local_app_path,
                                       description: "Path to the app (.app or .apk) built against the local SDK",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :local_sdk_version,
                                       description: "SDK version the local app was built against",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :flows_dir,
                                       description: "Directory containing the test case's #{BEFORE_UPDATE_FLOW}.yaml and #{AFTER_UPDATE_FLOW}.yaml flows",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :output_dir,
                                       description: "Directory to store the test output and JUnit reports in. Cleared before running",
                                       type: String,
                                       optional: false),
          FastlaneCore::ConfigItem.new(key: :max_attempts,
                                       description: "Maximum number of attempts of the whole sequence",
                                       type: Integer,
                                       optional: false)
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
            release_app_path: "build/release/SDKUpdateTester.app",
            release_sdk_version: "5.92.0",
            local_app_path: "build/local/SDKUpdateTester.app",
            local_sdk_version: "5.93.0-SNAPSHOT",
            flows_dir: "maestro/anonymous_user",
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
