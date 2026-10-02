describe Fastlane::Actions::RunSdkUpdateMaestroTestAction do
  describe '#run' do
    let(:tmp_dir) { Dir.mktmpdir }
    let(:flows_dir) { "#{tmp_dir}/maestro/anonymous_user" }
    let(:output_dir) { "#{tmp_dir}/output" }
    let(:release_app_path) { "#{tmp_dir}/release/SDKUpdateTester.app" }
    let(:local_app_path) { "#{tmp_dir}/local/SDKUpdateTester.app" }
    let(:commands) { [] }
    let(:maestro_failures) { [] }

    before do
      FileUtils.mkdir_p([flows_dir, release_app_path, local_app_path, "#{tmp_dir}/fastlane"])
      FileUtils.touch(["#{flows_dir}/1_before_update.yaml", "#{flows_dir}/2_after_update.yaml"])
      allow(FastlaneCore::FastlaneFolder).to receive(:path).and_return("#{tmp_dir}/fastlane")
      allow(Time).to receive(:now).and_return(Time.at(1_700_000_000))
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
        release_app_path: release_app_path,
        release_sdk_version: "5.92.0",
        local_app_path: local_app_path,
        local_sdk_version: "5.93.0-SNAPSHOT",
        flows_dir: flows_dir,
        output_dir: output_dir,
        max_attempts: max_attempts
      )
    end

    def maestro_commands
      commands.select { |command| command.first == "maestro" }
    end

    it 'runs the before update flow on the release app, then the after update flow on the local app' do
      expect(run_action).to be true

      expected_commands = [
        ["xcrun", "simctl", "uninstall", "booted", "com.revenuecat.SDKUpdateTester"],
        ["xcrun", "simctl", "install", "booted", release_app_path],
        maestro_commands[0],
        ["xcrun", "simctl", "install", "booted", local_app_path],
        maestro_commands[1]
      ]
      expect(commands.reject { |command| command.first == "git" }).to eq(expected_commands)
      expect(maestro_commands[0].last).to eq("#{flows_dir}/1_before_update.yaml")
      expect(maestro_commands[1].last).to eq("#{flows_dir}/2_after_update.yaml")
    end

    it 'passes the screenshots dir, expected SDK version and app user ID to the flows' do
      run_action

      expect(maestro_commands[0]).to include(
        "SCREENSHOTS_DIR=#{output_dir}/attempt_1/reference_screenshots",
        "EXPECTED_SDK_VERSION=5.92.0",
        "APP_USER_ID=sdk-update-test-abc1234-1700000000-1"
      )
      expect(maestro_commands[1]).to include(
        "SCREENSHOTS_DIR=#{output_dir}/attempt_1/reference_screenshots",
        "EXPECTED_SDK_VERSION=5.93.0-SNAPSHOT",
        "APP_USER_ID=sdk-update-test-abc1234-1700000000-1"
      )
    end

    it 'copies the JUnit reports to the junit directory' do
      run_action

      expect(Dir.children("#{output_dir}/junit")).to contain_exactly("1_before_update.xml", "2_after_update.xml")
    end

    it 'retries the whole sequence from a clean install with a new app user ID' do
      maestro_failures.push(false, true)

      expect(run_action).to be true

      expect(commands.count { |command| command.include?("uninstall") }).to eq(2)
      expect(maestro_commands.size).to eq(4)
      expect(maestro_commands[2]).to include("APP_USER_ID=sdk-update-test-abc1234-1700000000-2")
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

    it 'uses adb on android' do
      run_action(platform: "android")

      expect(commands).to include(
        ["adb", "uninstall", "com.revenuecat.SDKUpdateTester"],
        ["adb", "install", "-r", release_app_path],
        ["adb", "install", "-r", local_app_path]
      )
    end

    it 'fails when a flow is missing' do
      FileUtils.rm("#{flows_dir}/2_after_update.yaml")

      expect { run_action }
        .to raise_error(FastlaneCore::Interface::FastlaneError, "Flow not found: #{flows_dir}/2_after_update.yaml")
    end

    it 'fails when an app is missing' do
      FileUtils.rm_rf(local_app_path)

      expect { run_action }
        .to raise_error(FastlaneCore::Interface::FastlaneError, "App not found: #{local_app_path}")
    end
  end

  describe '#available_options' do
    it 'rejects unknown platforms' do
      option = Fastlane::Actions::RunSdkUpdateMaestroTestAction.available_options.find { |o| o.key == :platform }
      expect { option.verify!("windows") }.to raise_error(FastlaneCore::Interface::FastlaneError)
      expect { option.verify!("android") }.not_to raise_error
    end
  end
end
