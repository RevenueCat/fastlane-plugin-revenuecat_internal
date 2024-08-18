require 'nokogiri'
require 'scan'

module Fastlane
  module Actions
    class ScanWithFlakyTestRetriesAction < Action
      def self.run(params)
        param_values = params.values

        # Delete option that isn't part of scan
        number_of_flaky_retries = param_values.delete(:number_of_flaky_retries)

        # Delete option that is part of scan but we will replace
        output_directory = param_values.delete(:output_directory)

        Dir.mktmpdir do |dir|
          run_test_and_retries_if_needed(
            params: param_values,
            output_dir: dir,
            number_of_flaky_retries: number_of_flaky_retries
          )
        ensure
          source_dir = retry_output_dir(dir: dir, attempt: 0)
          destination_dir = output_directory

          FileUtils.mkdir_p(destination_dir)
          Dir.glob("#{source_dir}/*").each do |file|
            FileUtils.cp_r(file, destination_dir)
          end
        end
      end

      def self.retry_output_dir(dir:, attempt:)
        if attempt == 0
          File.join(dir, 'original')
        else
          File.join(dir, "retry_#{attempt}")
        end
      end

      def self.failed_tests_path(dir:)
        File.join(dir, 'failed_tests.txt')
      end

      def self.run_test_and_retries_if_needed(params:, output_dir:, number_of_flaky_retries:)
        artifact_dir = retry_output_dir(dir: output_dir, attempt: 0)
      
        failed_tests = nil
        (0..number_of_flaky_retries).each do |retry_attempt|
          # Print out retry number
          UI.message("Scan retry attempt #{retry_attempt} out of #{number_of_flaky_retries}") if retry_attempt > 0
      
          # Separate report dir for each retry
          report_dir = retry_output_dir(dir: output_dir, attempt: retry_attempt)
          report_path = File.join(report_dir, "report.junit")
      
          # This is where scan happens
          fail_build = retry_attempt == number_of_flaky_retries
          begin
            params_copy = params.clone
            params_copy[:fail_build] = fail_build
            params_copy[:only_testing] = failed_tests
            params_copy[:output_directory] = report_dir

            other_action.scan(**params_copy)
          ensure

            if retry_attempt == 0
              # Only copy original junit report
              # and save list of failed tests
              retry_scan_save_failed_tests(
                junit_report_path: report_path,
                copy_path: File.join(artifact_dir, 'report.junit.original'),
                failed_tests_path: failed_tests_path(dir: artifact_dir)
              )
            else
              # Copy retry junit report and merge with main
              # and save list of failed tests
              retry_scan_save_failed_tests(
                junit_report_path: report_path,
                copy_path: File.join(artifact_dir, "report.junit.retry.#{retry_attempt}"),
                merge_path: File.join(artifact_dir, "report.junit"),
                failed_tests_path: failed_tests_path(dir: artifact_dir)
              )
            end
          end
      
          # Break out of retry loop if no tests failed
          failed_tests = File.read(failed_tests_path(dir: artifact_dir)).split("\n")
          if failed_tests.empty?
            UI.message('No failed tests to retry')
            break
          end
        end
      end

      def self.retry_scan_save_failed_tests(junit_report_path:, copy_path:, merge_path: nil, failed_tests_path:)
        report_path = junit_report_path
        report_path = File.absolute_path(report_path)

        # original
        FileUtils.cp(report_path, copy_path)

        save_failed_tests(report_path: report_path, failed_tests_path: failed_tests_path)

        if merge_path
          merge_and_replace_junit(report_path, merge_path)
        end
      end

      def self.merge_and_replace_junit(retry_report_path, original_report)
        merged_report = merge_reports(original_report, retry_report_path)
        save_report(merged_report, original_report)
    
        UI.message "Merged report saved to #{original_report}"
      end

      def self.parse_report(file_path)
        Nokogiri::XML(File.open(file_path))
      end
      
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
      
          if original_testcase
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
      
      def self.save_report(doc, output_path)
        File.open(output_path, 'w') { |file| file.write(doc.to_xml) }
      end

      def self.save_failed_tests(report_path:, failed_tests_path:)
        failed_tests = []
        
        if File.exist?(report_path)
          doc = Nokogiri::XML(File.open(report_path))
      
          doc.xpath('//testcase[failure]').each do |test_case|
            suitename = test_case.parent['name'] # Retrieve the suitename
            classname = test_case['classname']
            name = test_case['name']
            failed_tests << "#{suitename}/#{classname}/#{name}"
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
        'A short description with <= 80 characters of what this action does'
      end

      def self.details
        'You can use this action to do cool things...'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :number_of_flaky_retries,
                                       description: 'Number of flaky retries',
                                       type: Integer,
                                       optional: false)
        ] + FastlaneCore::CommanderGenerator.new.generate(Scan::Options.available_options)
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
