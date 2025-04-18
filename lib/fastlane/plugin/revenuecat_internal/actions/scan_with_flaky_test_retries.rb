require 'nokogiri'
require 'scan'
require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Actions
    class ScanWithFlakyTestRetriesAction < Action
      def self.run(params)
        # Pulling out the values from Fastlane::Configurations to
        # modify and pass into `scan`
        param_values = params.values

        # Delete option that isn't part of scan
        number_of_flaky_retries = param_values.delete(:number_of_flaky_retries)

        if number_of_flaky_retries == 0
          # Run scan directly if no retries are needed
          other_action.scan(**param_values)
        else
          # Delete option that is part of scan but we will replace
          output_directory = param_values.delete(:output_directory)

          # Storing all scan output in a separate temp directory
          Dir.mktmpdir do |temp_dir|
            temp_artifacts_dir = File.join(temp_dir, 'original')

            last_attempt = run_test_and_retries_if_needed(
              params: param_values,
              output_dir: temp_dir,
              artifacts_dir: temp_artifacts_dir,
              number_of_flaky_retries: number_of_flaky_retries
            )
          ensure
            # Copies outputs from temp artifact directory to the one specificed in scan option
            source_dir = File.join(temp_artifacts_dir, '.')
            destination_dir = output_directory

            UI.message("Copying '#{source_dir}' to '#{destination_dir}'")
            sh("ls -al #{source_dir}")

            FileUtils.mkdir_p(destination_dir)
            FileUtils.cp_r(source_dir, destination_dir)

            if last_attempt == 0
              UI.success("Finished tests without any retries!")
            else
              UI.important("Finished running scan with flaky test retries")
              UI.important("Retried flaky tests: #{last_attempt} time(s)")
            end
          end
        end
      end

      # Runs the initial tests and any retry iterations if needed
      #
      # @param params [Hash] The params to pass to scan
      # @param output_dir [String] The output dir for this iteration of test
      # @param artifacts_dir [String] The dir where all scan retry artifacts will go
      # @param number_of_flaky_retries [Integer] The number of times to retry flaky tests
      def self.run_test_and_retries_if_needed(params:, output_dir:, artifacts_dir:, number_of_flaky_retries:)
        failed_tests_path = File.join(output_dir, 'failed_tests.txt')

        last_attempt = 0
        failed_tests = nil
        (0..number_of_flaky_retries).each do |attempt|
          last_attempt = attempt
          UI.message("Scan retry attempt #{attempt} out of #{number_of_flaky_retries}") if attempt > 0

          # Separate report dir for each retry
          report_dir = attempt == 0 ? artifacts_dir : File.join(output_dir, "retry_#{attempt}")
          report_path = File.join(report_dir, "report.junit")

          # Run tests
          fail_build = attempt == number_of_flaky_retries
          begin
            params_copy = params.clone
            params_copy[:fail_build] = fail_build
            params_copy[:only_testing] = failed_tests
            params_copy[:output_directory] = report_dir

            # Can't specify a test plan there are failed tests
            params_copy.delete(:testplan) if failed_tests

            other_action.scan(**params_copy)
          ensure
            if attempt == 0
              # Only copy original junit report and save list of failed tests
              move_junit_and_save_failed_tests(
                source_path: report_path,
                destination_path: File.join(artifacts_dir, 'report.junit.original'),
                failed_tests_path: failed_tests_path
              )
            else
              # Copy retry junit report and merge with main and save list of failed tests
              move_junit_and_save_failed_tests(
                source_path: report_path,
                destination_path: File.join(artifacts_dir, "report.junit.retry.#{attempt}"),
                merge_path: File.join(artifacts_dir, "report.junit"),
                failed_tests_path: failed_tests_path
              )
            end
          end

          # Break out of retry loop if no tests failed
          failed_tests = File.read(failed_tests_path).split("\n")
          if failed_tests.empty?
            UI.verbose('No failed tests to retry')
            break
          end
        end

        return last_attempt
      end

      # Copies the junit file to a new location (and a new name).
      # Saves the failed tests to a text file for the next retry run.
      #
      # @param source_path [String] The path of the junit file
      # @param destination_path [String] The path where the junit file should be moved to
      # @param failed_tests_path [String] The path where failed tests should be saved
      def self.move_junit_and_save_failed_tests(source_path:, destination_path:, failed_tests_path:, merge_path: nil)
        # Copy to junit report to
        FileUtils.cp(source_path, destination_path)

        save_failed_tests(report_path: source_path, failed_tests_path: failed_tests_path)

        # Need to merge if not the first run
        if merge_path
          merge_and_replace_junit(source_path, merge_path)
        end
      end

      # Merges the first junit report into the second.
      #
      # @param retry_report_path [String] The path of the retry junit file
      # @param original_report [String] The path where the original junit file
      def self.merge_and_replace_junit(retry_report_path, original_report)
        merged_report = merge_reports(original_report, retry_report_path)
        save_report(merged_report, original_report)

        UI.message("Merged report saved to #{original_report}")
      end

      def self.parse_report(file_path)
        Nokogiri::XML(File.open(file_path))
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def self.merge_reports(original_report, retry_report)
        original_doc = parse_report(original_report)
        retry_doc = parse_report(retry_report)

        original_testcases = original_doc.xpath('//testcase')
        retry_testcases = retry_doc.xpath('//testcase')

        retry_count = 0

        retry_testcases.each do |retry_testcase|
          suitename = retry_testcase.parent['name'] # Retrieve suitename
          classname = retry_testcase['classname']
          name = retry_testcase['name']

          original_testcase = original_testcases.find do |tc|
            tc['classname'] == classname && tc['name'] == name && tc.parent['name'] == suitename
          end

          next unless original_testcase

          original_testcase.at('failure')&.remove # Remove failure from original

          retry_failure = retry_testcase.at('failure')

          if retry_failure
            # Clone the failure node from retry_testcase and add it to original_testcase
            original_testcase.add_child(retry_failure.clone)
          end

          # Add retry count attribute to the testcase
          current_retry_count = original_testcase['retry_count'].to_i
          original_testcase['retry_count'] = (current_retry_count + 1).to_s

          retry_count += 1
        end

        # Add total retry count as a property in the testsuite
        properties_node = original_doc.at('testsuite > properties') || Nokogiri::XML::Node.new('properties', original_doc.at('testsuite'))
        original_doc.at('testsuite').add_child(properties_node) unless original_doc.at('testsuite > properties')

        retry_property = Nokogiri::XML::Node.new('property', original_doc)
        retry_property['name'] = 'total_retries'
        retry_property['value'] = retry_count.to_s

        properties_node.add_child(retry_property)

        original_doc
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.save_report(doc, output_path)
        File.write(output_path, doc.to_xml)
      end

      # Saves all the failed method signatures into a text field from a junit report
      # Only records tests that failed and didn't succeed in retries
      #
      # @param report_path [String] The path of the junit file
      # @param failed_tests_path [String] The path where failed tests should be saved
      def self.save_failed_tests(report_path:, failed_tests_path:)
        failed_tests = []

        if File.exist?(report_path)
          doc = Nokogiri::XML(File.open(report_path))

          # Get all test cases
          all_test_cases = doc.xpath('//testcase')

          # Group test cases by their unique identifier (suitename/classname/name)
          test_cases_by_id = {}

          all_test_cases.each do |test_case|
            suitename = test_case.parent['name'] # Retrieve the suitename
            classname = test_case['classname']
            name = test_case['name']
            test_id = "#{suitename}/#{classname}/#{name}"

            test_cases_by_id[test_id] ||= []
            test_cases_by_id[test_id] << test_case
          end

          # For each test, check if it has a failure and no successful retry
          test_cases_by_id.each do |test_id, test_cases|
            # Find test cases with failures
            failed_cases = test_cases.select { |tc| tc.at('failure') }

            # Find test cases without failures (successful retries)
            successful_cases = test_cases.select { |tc| !tc.at('failure') }

            # If there are failed cases but no successful retries, add to failed tests
            if !failed_cases.empty? && successful_cases.empty?
              failed_tests << test_id
            end
          end

          failed_tests = failed_tests.uniq

          File.open(failed_tests_path, 'w') do |file|
            file.puts(failed_tests)
          end
        end
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        'Retry flaky tests in a new scan run'
      end

      def self.details
        'Retry flaky tests in a new scan run'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :number_of_flaky_retries,
                                       description: 'Number of flaky retries',
                                       type: Integer,
                                       optional: false)
        ] + Scan::Options.available_options
      end

      def self.authors
        ['joshdholtz']
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
