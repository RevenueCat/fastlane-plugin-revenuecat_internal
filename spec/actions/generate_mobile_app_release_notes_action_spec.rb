describe Fastlane::Actions::GenerateMobileAppReleaseNotesAction do
  describe '#run' do
    let(:changes) { "- Added a chart to the Active Users card\n- Updated the RevenueCat SDK" }
    let(:success_status) { instance_double(Process::Status, success?: true) }
    let(:failure_status) { instance_double(Process::Status, success?: false) }

    it 'sends the prompt with the changes to the claude cli and returns the output' do
      expect(Open3).to receive(:capture3) do |*command, stdin_data:|
        expect(command).to eq(['claude', '-p', '--model', 'claude-sonnet-4-6'])
        expect(stdin_data).to include(changes)
        expect(stdin_data).to include("App Store")
        ["• Generated notes\n", '', success_status]
      end
      result = Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
        changes: changes,
        platform: 'ios',
        claude_binary: 'claude',
        model: 'claude-sonnet-4-6'
      )
      expect(result).to eq('• Generated notes')
    end

    it 'includes the google play length limit for android' do
      expect(Open3).to receive(:capture3) do |*_command, stdin_data:|
        expect(stdin_data).to include("Google Play")
        expect(stdin_data).to include("must not exceed 500 characters")
        ['• Generated notes', '', success_status]
      end
      Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
        changes: changes,
        platform: 'android'
      )
    end

    it 'includes the app store length limit for ios' do
      expect(Open3).to receive(:capture3) do |*_command, stdin_data:|
        expect(stdin_data).to include("App Store")
        expect(stdin_data).to include("must not exceed 4000 characters")
        ['• Generated notes', '', success_status]
      end
      Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
        changes: changes,
        platform: 'ios'
      )
    end

    it 'uses a custom max_length in the prompt and enforces it on the output' do
      expect(Open3).to receive(:capture3) do |*_command, stdin_data:|
        expect(stdin_data).to include("must not exceed 20 characters")
        ['this is way too long to fit in twenty characters', '', success_status]
      end
      expect do
        Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
          changes: changes,
          platform: 'ios',
          max_length: 20
        )
      end.to raise_exception(FastlaneCore::Interface::FastlaneError, /exceeds the 20 character limit for 'ios'/)
    end

    it 'fails when the output exceeds the store limit' do
      allow(Open3).to receive(:capture3).and_return(['x' * 501, '', success_status])
      expect do
        Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
          changes: changes,
          platform: 'android'
        )
      end.to raise_exception(FastlaneCore::Interface::FastlaneError, /501 characters, which exceeds the 500 character limit for 'android'/)
    end

    it 'uses the given claude binary and model' do
      expect(Open3).to receive(:capture3) do |*command, stdin_data:|
        expect(command).to eq(['/usr/local/bin/claude', '-p', '--model', 'claude-fable-5'])
        ['• Generated notes', '', success_status]
      end
      Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
        changes: changes,
        platform: 'ios',
        claude_binary: '/usr/local/bin/claude',
        model: 'claude-fable-5'
      )
    end

    it 'fails for an unsupported platform' do
      expect do
        Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
          changes: changes,
          platform: 'roku'
        )
      end.to raise_exception(FastlaneCore::Interface::FastlaneError, /Unsupported platform 'roku'/)
    end

    it 'fails when the claude cli fails' do
      allow(Open3).to receive(:capture3).and_return(['', 'boom', failure_status])
      expect do
        Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
          changes: changes,
          platform: 'ios'
        )
      end.to raise_exception(FastlaneCore::Interface::FastlaneError, /failed: boom/)
    end

    it 'fails when the claude cli times out' do
      allow(Open3).to receive(:capture3).and_raise(Timeout::Error)
      expect do
        Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
          changes: changes,
          platform: 'ios',
          timeout: 5
        )
      end.to raise_exception(FastlaneCore::Interface::FastlaneError, /timed out after 5 seconds/)
    end

    it 'fails when the output is empty' do
      allow(Open3).to receive(:capture3).and_return(["\n", '', success_status])
      expect do
        Fastlane::Actions::GenerateMobileAppReleaseNotesAction.run(
          changes: changes,
          platform: 'ios'
        )
      end.to raise_exception(FastlaneCore::Interface::FastlaneError, /empty output/)
    end
  end
end
