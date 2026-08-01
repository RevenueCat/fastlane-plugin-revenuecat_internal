require 'tmpdir'
require 'fileutils'

describe Fastlane::Actions::ScanWithFlakyTestRetriesAction do
  describe '.run_test_and_retries_if_needed' do
    let(:params) do
      {
        scheme: 'AppScheme',
        testplan: 'UITests',
        output_directory: 'ignored'
      }
    end

    let(:temp_dir) { Dir.mktmpdir }
    let(:artifacts_dir) { File.join(temp_dir, 'artifacts') }
    let(:other_action_double) { double('OtherAction') }

    before do
      FileUtils.mkdir_p(artifacts_dir)

      allow(described_class).to receive(:other_action).and_return(other_action_double)
    end

    after do
      FileUtils.remove_entry(temp_dir)
    end

    context 'when the initial run passes without failures' do
      let(:failed_tests_outputs) { [''] }

      before do
        outputs = failed_tests_outputs.dup
        allow(described_class).to receive(:move_junit_and_save_failed_tests) do |source_path:, destination_path:, failed_tests_path:, merge_path: nil|
          FileUtils.mkdir_p(File.dirname(failed_tests_path))
          content = outputs.shift
          File.write(failed_tests_path, (content || ''))
        end
      end

      it 'does not pass only_testing and keeps the testplan' do
        expect(other_action_double).to receive(:scan) do |**scan_params|
          expect(scan_params).not_to have_key(:only_testing)
          expect(scan_params[:testplan]).to eq('UITests')
        end

        result = described_class.run_test_and_retries_if_needed(
          params: params,
          output_dir: temp_dir,
          artifacts_dir: artifacts_dir,
          number_of_flaky_retries: 1
        )

        expect(result).to eq(0)
      end
    end

    context 'when retries are required for failed tests' do
      let(:failed_tests_outputs) { ['Suite/Class/test_method', ''] }

      before do
        outputs = failed_tests_outputs.dup
        allow(described_class).to receive(:move_junit_and_save_failed_tests) do |source_path:, destination_path:, failed_tests_path:, merge_path: nil|
          FileUtils.mkdir_p(File.dirname(failed_tests_path))
          content = outputs.shift
          File.write(failed_tests_path, (content || ''))
        end
      end

      it 'retries with only_testing and removes the testplan' do
        # First scan invocation: initial run still uses the full test plan
        expect(other_action_double).to receive(:scan).ordered do |**scan_params|
          expect(scan_params).not_to have_key(:only_testing)
          expect(scan_params[:testplan]).to eq('UITests')
        end

        # Second invocation: retry run scoped to failed tests and without the plan
        expect(other_action_double).to receive(:scan).ordered do |**scan_params|
          expect(scan_params[:only_testing]).to eq(['Suite/Class/test_method'])
          expect(scan_params).not_to have_key(:testplan)
        end

        result = described_class.run_test_and_retries_if_needed(
          params: params,
          output_dir: temp_dir,
          artifacts_dir: artifacts_dir,
          number_of_flaky_retries: 2
        )

        expect(result).to eq(1)
      end
    end
  end
end