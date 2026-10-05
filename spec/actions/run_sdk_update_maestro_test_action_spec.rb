describe Fastlane::Actions::RunSdkUpdateMaestroTestAction do
  describe '#run' do
    let(:tmp_dir) { Dir.mktmpdir }
    let(:flows_dir) { "#{tmp_dir}/maestro/anonymous_user" }
    let(:before_update_flow) { "#{flows_dir}/before_update.yaml" }
    let(:after_update_flow) { "#{flows_dir}/after_update.yaml" }
    let(:output_dir) { "#{tmp_dir}/output" }
    let(:release_app_path) { "#{tmp_dir}/release/SDKUpdateTester.app" }
    let(:local_app_path) { "#{tmp_dir}/local/SDKUpdateTester.app" }
    let(:steps) do
      [
        { app_path: release_app_path, sdk_version: "5.92.0", flow: before_update_flow },
        { app_path: local_app_path, sdk_version: "5.93.0-SNAPSHOT", flow: after_update_flow }
      ]
    end
    let(:commands) { [] }
    let(:maestro_failures) { [] }

    before do
      FileUtils.mkdir_p([flows_dir, release_app_path, local_app_path, "#{tmp_dir}/fastlane"])
      FileUtils.touch([before_update_flow, after_update_flow])
      allow(FastlaneCore::FastlaneFolder).to receive(:path).and_return("#{tmp_dir}/fastlane")
      allow(SecureRandom).to receive(:hex).with(4).and_return("1a2b3c4d")
      allow(Fastlane::UI).to receive(:message)
      allow(Fastlane::UI).to receive(:error)
      allow(Fastlane::UI).to receive(:success)

      allow(Fastlane::Actions).to receive(:sh) do |*command, **_options|
        commands << command
        next "abc1234\n" if command.first(2) == %w[git rev-parse]
        next unless command.first == "maestro"

        report = command[command.index("--output") + 1]
        FileUtils.mkdir_p(File.dirname(report))
        File.write(report, "<testsuites/>")
        raise StandardError, "Maestro failed" if maestro_failures.shift
      end
    end

    after { FileUtils.rm_rf(tmp_dir) }

    def run_action(platform: "ios", max_attempts: 3)
      Fastlane::Actions::RunSdkUpdateMaestroTestAction.run(
        platform: platform,
        app_id: "com.revenuecat.SDKUpdateTester",
        steps: steps,
        output_dir: output_dir,
        max_attempts: max_attempts
      )
    end

    def maestro_commands
      commands.select { |command| command.first == "maestro" }
    end

    it 'resets the simulator, then installs each app over the previous one and runs its flow' do
      expect(run_action).to be true

      expected_commands = [
        ["xcrun", "simctl", "uninstall", "booted", "com.revenuecat.SDKUpdateTester"],
        ["xcrun", "simctl", "keychain", "booted", "reset"],
        ["xcrun", "simctl", "install", "booted", release_app_path],
        maestro_commands[0],
        ["xcrun", "simctl", "install", "booted", local_app_path],
        maestro_commands[1]
      ]
      expect(commands.reject { |command| command.first == "git" }).to eq(expected_commands)
      expect(maestro_commands[0].last).to eq(before_update_flow)
      expect(maestro_commands[1].last).to eq(after_update_flow)
    end

    it 'passes the screenshots dir, expected SDK version and app user ID to the flows' do
      run_action

      expect(maestro_commands[0]).to include(
        "SCREENSHOTS_DIR=#{output_dir}/attempt_1/reference_screenshots",
        "EXPECTED_SDK_VERSION=5.92.0",
        "APP_USER_ID=sdk-update-test-abc1234-1-1a2b3c4d"
      )
      expect(maestro_commands[1]).to include(
        "SCREENSHOTS_DIR=#{output_dir}/attempt_1/reference_screenshots",
        "EXPECTED_SDK_VERSION=5.93.0-SNAPSHOT",
        "APP_USER_ID=sdk-update-test-abc1234-1-1a2b3c4d"
      )
    end

    it 'names the JUnit reports after the step number and flow' do
      run_action

      expect(Dir.children("#{output_dir}/junit")).to contain_exactly("1_before_update.xml", "2_after_update.xml")
    end

    it 'supports more than two steps, even reusing a flow' do
      older_app_path = "#{tmp_dir}/older/SDKUpdateTester.app"
      FileUtils.mkdir_p(older_app_path)
      steps.unshift({ app_path: older_app_path, sdk_version: "4.43.0", flow: before_update_flow })

      run_action

      installed_apps = commands.select { |command| command.include?("install") }.map(&:last)
      expect(installed_apps).to eq([older_app_path, release_app_path, local_app_path])
      expect(maestro_commands.map(&:last)).to eq([before_update_flow, before_update_flow, after_update_flow])
      expect(Dir.children("#{output_dir}/junit"))
        .to contain_exactly("1_before_update.xml", "2_before_update.xml", "3_after_update.xml")
    end

    it 'resolves relative paths from the fastlane directory' do
      steps[0][:flow] = "../maestro/anonymous_user/before_update.yaml"

      run_action

      expect(maestro_commands[0].last).to eq(before_update_flow)
    end

    it 'retries the whole sequence from a clean state with a new app user ID' do
      maestro_failures.push(false, true)

      expect(run_action).to be true

      expect(commands.count { |command| command.include?("uninstall") }).to eq(2)
      expect(commands.count { |command| command.include?("keychain") }).to eq(2)
      expect(maestro_commands.size).to eq(4)
      expect(maestro_commands[2]).to include("APP_USER_ID=sdk-update-test-abc1234-2-1a2b3c4d")
      expect(maestro_commands[2]).to include("SCREENSHOTS_DIR=#{output_dir}/attempt_2/reference_screenshots")
    end

    it 'only keeps the JUnit reports of the last attempt' do
      maestro_failures.push(true)

      run_action

      expect(Dir.children("#{output_dir}/junit")).to contain_exactly("1_before_update.xml", "2_after_update.xml")
    end

    it 'raises the last error after exhausting all attempts' do
      maestro_failures.push(true, true)

      expect { run_action(max_attempts: 2) }.to raise_error(StandardError, "Maestro failed")
      expect(maestro_commands.size).to eq(2)
      expect(Dir.children("#{output_dir}/junit")).to contain_exactly("1_before_update.xml")
    end

    it 'uses adb on android, without resetting any keychain' do
      run_action(platform: "android")

      expect(commands).to include(
        ["adb", "uninstall", "com.revenuecat.SDKUpdateTester"],
        ["adb", "install", "-r", release_app_path],
        ["adb", "install", "-r", local_app_path]
      )
      expect(commands.none? { |command| command.include?("keychain") }).to be true
    end

    it 'fails when a flow is missing' do
      FileUtils.rm(after_update_flow)

      expect { run_action }
        .to raise_error(FastlaneCore::Interface::FastlaneError, "Flow not found: #{after_update_flow}")
    end

    it 'fails when an app is missing' do
      FileUtils.rm_rf(local_app_path)

      expect { run_action }
        .to raise_error(FastlaneCore::Interface::FastlaneError, "App not found: #{local_app_path}")
    end
  end

  describe '#available_options' do
    def option(key)
      Fastlane::Actions::RunSdkUpdateMaestroTestAction.available_options.find { |o| o.key == key }
    end

    it 'rejects unknown platforms' do
      expect { option(:platform).verify!("windows") }.to raise_error(FastlaneCore::Interface::FastlaneError)
      expect { option(:platform).verify!("android") }.not_to raise_error
    end

    it 'rejects zero max attempts' do
      expect { option(:max_attempts).verify!(0) }
        .to raise_error(FastlaneCore::Interface::FastlaneError, "max_attempts must be greater than 0")
    end

    it 'rejects negative max attempts' do
      expect { option(:max_attempts).verify!(-1) }
        .to raise_error(FastlaneCore::Interface::FastlaneError, "max_attempts must be greater than 0")
    end

    it 'accepts positive max attempts' do
      expect { option(:max_attempts).verify!(1) }.not_to raise_error
      expect { option(:max_attempts).verify!(3) }.not_to raise_error
    end

    it 'requires at least two complete steps' do
      step = { app_path: "app", sdk_version: "1.0.0", flow: "flow.yaml" }

      expect { option(:steps).verify!([step]) }.to raise_error(FastlaneCore::Interface::FastlaneError, /at least 2 steps/)
      expect { option(:steps).verify!([step, step.reject { |key, _| key == :flow }]) }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /Each step needs app_path, sdk_version, flow/)
      expect { option(:steps).verify!([step, "not a step"]) }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /Each step needs/)
      expect { option(:steps).verify!([step, step]) }.not_to raise_error
    end
  end
end
