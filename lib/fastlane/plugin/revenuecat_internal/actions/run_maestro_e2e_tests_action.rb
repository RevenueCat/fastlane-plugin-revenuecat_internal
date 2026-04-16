require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fileutils'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class RunMaestroE2eTestsAction < Action
      def self.run(params)
        # Fastlane's sh() resolves relative paths from the fastlane/ directory,
        # but Ruby File operations resolve from the process cwd (project root).
        # Resolve all paths relative to the fastlane/ directory for consistency.
        fastlane_dir = FastlaneCore::FastlaneFolder.path
        flow_dir = File.expand_path(params[:flow_dir], fastlane_dir)
        output_dir = File.expand_path(params[:output_dir], fastlane_dir)
        max_retries = params[:max_retries]
        environment_name = params[:environment_name]

        UI.user_error!("Flow directory not found: #{flow_dir}") unless File.directory?(flow_dir)

        FileUtils.mkdir_p(output_dir)

        success = false
        attempt = 0

        while attempt <= max_retries && !success
          attempt_output_dir = "#{output_dir}/attempt_#{attempt}"
          FileUtils.mkdir_p(attempt_output_dir)

          begin
            Actions.sh("maestro", "test", "--format", "junit", "--output", "#{attempt_output_dir}/report.xml", "--test-output-dir", attempt_output_dir, flow_dir)
            success = true
            postprocess_junit_report(attempt_output_dir, environment_name) if environment_name
            FileUtils.cp("#{attempt_output_dir}/report.xml", "#{output_dir}/report.xml")
          rescue StandardError => e
            UI.error("Maestro test attempt #{attempt} failed: #{e.message}")
            postprocess_junit_report(attempt_output_dir, environment_name) if environment_name
            raise e if attempt >= max_retries

            attempt += 1
            UI.message("Retrying... #{attempt}/#{max_retries}")
          end
        end

        success
      end

      # Appends the environment name to each <testcase> name attribute in the JUnit XML report.
      # This is needed because purchases-ios runs Maestro tests against multiple backend
      # environments (e.g. production, sandbox) in the same CI job. Without this, CircleCI
      # merges identically-named test cases from different environments into a single entry,
      # making it impossible to tell which environment a failure came from.
      def self.postprocess_junit_report(output_dir, environment_name)
        junit_file = "#{output_dir}/report.xml"
        return unless File.exist?(junit_file)

        UI.message("Adding environment name (#{environment_name}) to test names in JUnit report...")
        content = File.read(junit_file)
        modified_content = content.gsub(/<testcase([^>]*)name="([^"]+)"/) do |_match|
          prefix = Regexp.last_match(1)
          test_name = Regexp.last_match(2)
          "<testcase#{prefix}name=\"#{test_name} (#{environment_name})\""
        end
        File.write(junit_file, modified_content)
      end

      def self.description
        "Runs Maestro E2E tests with automatic retries to handle flaky failures"
      end

      def self.authors
        ["Antonio Pallares"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :flow_dir,
                                       description: "Path to the Maestro flow directory",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :output_dir,
                                       description: "Path to store test output and JUnit reports",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :max_retries,
                                       description: "Maximum number of retry attempts after initial failure",
                                       optional: true,
                                       default_value: 5,
                                       type: Integer),
          FastlaneCore::ConfigItem.new(key: :environment_name,
                                       description: "Optional environment name to prefix in JUnit test case names (used by purchases-ios for multi-environment runs)",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.return_value
        "Returns true if tests passed (possibly after retries), raises on final failure"
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
