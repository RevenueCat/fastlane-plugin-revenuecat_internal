describe Fastlane::Actions::RunMaestroE2eTestsAction do
  describe '#run' do
    let(:flow_dir) { '/tmp/maestro_test_flows' }
    let(:output_dir) { '/tmp/maestro_test_output' }

    before do
      allow(File).to receive(:directory?).and_call_original
      allow(File).to receive(:directory?).with(flow_dir).and_return(true)
      allow(FileUtils).to receive(:mkdir_p)
      allow(FileUtils).to receive(:cp)
    end

    context 'when flow directory does not exist' do
      it 'raises a user error' do
        allow(File).to receive(:directory?).with('/nonexistent').and_return(false)

        expect(Fastlane::UI).to receive(:user_error!).with("Flow directory not found: /nonexistent")

        Fastlane::Actions::RunMaestroE2eTestsAction.run(
          flow_dir: '/nonexistent',
          output_dir: output_dir,
          max_retries: 5
        )
      end
    end

    context 'when maestro succeeds on first attempt' do
      it 'returns true without retrying' do
        expect(Fastlane::Actions).to receive(:sh).once

        result = Fastlane::Actions::RunMaestroE2eTestsAction.run(
          flow_dir: flow_dir,
          output_dir: output_dir,
          max_retries: 5
        )

        expect(result).to be true
      end

      it 'copies the report to the main output directory' do
        allow(Fastlane::Actions).to receive(:sh)
        expect(FileUtils).to receive(:cp).with("#{output_dir}/attempt_0/report.xml", "#{output_dir}/report.xml")

        Fastlane::Actions::RunMaestroE2eTestsAction.run(
          flow_dir: flow_dir,
          output_dir: output_dir,
          max_retries: 5
        )
      end
    end

    context 'when maestro fails then succeeds on retry' do
      it 'retries and returns true' do
        call_count = 0
        allow(Fastlane::Actions).to receive(:sh) do
          call_count += 1
          raise StandardError, "Maestro failed" if call_count == 1
        end
        allow(Fastlane::UI).to receive(:error)
        allow(Fastlane::UI).to receive(:message)

        result = Fastlane::Actions::RunMaestroE2eTestsAction.run(
          flow_dir: flow_dir,
          output_dir: output_dir,
          max_retries: 5
        )

        expect(result).to be true
        expect(call_count).to eq(2)
      end

      it 'logs the failure and retry messages' do
        first_call = true
        allow(Fastlane::Actions).to receive(:sh) do
          if first_call
            first_call = false
            raise StandardError, "Maestro failed"
          end
        end

        expect(Fastlane::UI).to receive(:error).with("Maestro test attempt 0 failed: Maestro failed")
        expect(Fastlane::UI).to receive(:message).with("Retrying... 1/5")

        Fastlane::Actions::RunMaestroE2eTestsAction.run(
          flow_dir: flow_dir,
          output_dir: output_dir,
          max_retries: 5
        )
      end
    end

    context 'when maestro fails all retries' do
      it 'raises the last error after exhausting retries' do
        allow(Fastlane::Actions).to receive(:sh).and_raise(StandardError, "Maestro failed")
        allow(Fastlane::UI).to receive(:error)
        allow(Fastlane::UI).to receive(:message)

        expect do
          Fastlane::Actions::RunMaestroE2eTestsAction.run(
            flow_dir: flow_dir,
            output_dir: output_dir,
            max_retries: 2
          )
        end.to raise_error(StandardError, "Maestro failed")
      end

      it 'attempts exactly max_retries + 1 times' do
        call_count = 0
        allow(Fastlane::Actions).to receive(:sh) do
          call_count += 1
          raise StandardError, "Maestro failed"
        end
        allow(Fastlane::UI).to receive(:error)
        allow(Fastlane::UI).to receive(:message)

        begin
          Fastlane::Actions::RunMaestroE2eTestsAction.run(
            flow_dir: flow_dir,
            output_dir: output_dir,
            max_retries: 2
          )
        rescue StandardError
          nil
        end

        expect(call_count).to eq(3)
      end
    end

    context 'with environment_name parameter' do
      it 'does not call postprocess when environment_name is nil' do
        allow(Fastlane::Actions).to receive(:sh)
        expect(Fastlane::Actions::RunMaestroE2eTestsAction).not_to receive(:postprocess_junit_report)

        Fastlane::Actions::RunMaestroE2eTestsAction.run(
          flow_dir: flow_dir,
          output_dir: output_dir,
          max_retries: 5
        )
      end

      it 'calls postprocess on success when environment_name is set' do
        allow(Fastlane::Actions).to receive(:sh)
        expect(Fastlane::Actions::RunMaestroE2eTestsAction).to receive(:postprocess_junit_report)
          .with("#{output_dir}/attempt_0", "sandbox")

        Fastlane::Actions::RunMaestroE2eTestsAction.run(
          flow_dir: flow_dir,
          output_dir: output_dir,
          max_retries: 5,
          environment_name: "sandbox"
        )
      end

      it 'calls postprocess on failure when environment_name is set' do
        allow(Fastlane::Actions).to receive(:sh).and_raise(StandardError, "fail")
        allow(Fastlane::UI).to receive(:error)
        expect(Fastlane::Actions::RunMaestroE2eTestsAction).to receive(:postprocess_junit_report)
          .with("#{output_dir}/attempt_0", "sandbox")

        begin
          Fastlane::Actions::RunMaestroE2eTestsAction.run(
            flow_dir: flow_dir,
            output_dir: output_dir,
            max_retries: 0,
            environment_name: "sandbox"
          )
        rescue StandardError
          nil
        end
      end
    end
  end

  describe '.postprocess_junit_report' do
    let(:output_dir) { Dir.mktmpdir }
    let(:junit_file) { "#{output_dir}/report.xml" }

    after { FileUtils.rm_rf(output_dir) }

    it 'appends environment name to testcase names' do
      File.write(junit_file, <<~XML)
        <testsuite>
          <testcase classname="e2e" name="purchase_through_paywall" time="10.5"/>
          <testcase classname="e2e" name="restore_purchases" time="5.2"/>
        </testsuite>
      XML

      Fastlane::Actions::RunMaestroE2eTestsAction.postprocess_junit_report(output_dir, "sandbox")

      content = File.read(junit_file)
      expect(content).to include('name="purchase_through_paywall (sandbox)"')
      expect(content).to include('name="restore_purchases (sandbox)"')
    end

    it 'does nothing when the report file does not exist' do
      expect { Fastlane::Actions::RunMaestroE2eTestsAction.postprocess_junit_report(output_dir, "sandbox") }
        .not_to raise_error
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::RunMaestroE2eTestsAction.available_options.size).to eq(4)
    end

    it 'has required flow_dir option' do
      option = Fastlane::Actions::RunMaestroE2eTestsAction.available_options.find { |o| o.key == :flow_dir }
      expect(option.optional).to be false
    end

    it 'has required output_dir option' do
      option = Fastlane::Actions::RunMaestroE2eTestsAction.available_options.find { |o| o.key == :output_dir }
      expect(option.optional).to be false
    end

    it 'has optional max_retries with default of 5' do
      option = Fastlane::Actions::RunMaestroE2eTestsAction.available_options.find { |o| o.key == :max_retries }
      expect(option.optional).to be true
      expect(option.default_value).to eq(5)
    end

    it 'has optional environment_name' do
      option = Fastlane::Actions::RunMaestroE2eTestsAction.available_options.find { |o| o.key == :environment_name }
      expect(option.optional).to be true
    end
  end

  describe 'action metadata' do
    it 'has a description' do
      expect(Fastlane::Actions::RunMaestroE2eTestsAction.description).not_to be_empty
    end

    it 'supports all platforms' do
      expect(Fastlane::Actions::RunMaestroE2eTestsAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::RunMaestroE2eTestsAction.is_supported?(:android)).to be true
    end
  end
end
