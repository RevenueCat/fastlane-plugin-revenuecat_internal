describe Fastlane::Actions::GetLatestReleaseBeforeVersionAction do
  describe '#run' do
    let(:ls_remote_output) do
      [
        "aaa\trefs/tags/5.91.0",
        "bbb\trefs/tags/5.92.0",
        "ccc\trefs/tags/5.92.1",
        "ddd\trefs/tags/5.93.0-beta.1",
        "eee\trefs/tags/5.93.0",
        "fff\trefs/tags/5.100.0",
        "ggg\trefs/tags/not-a-version"
      ].join("\n")
    end

    before do
      allow(Fastlane::Actions).to receive(:sh)
        .with("git", "ls-remote", "--tags", "--refs", "https://github.com/RevenueCat/purchases-ios-spm.git", log: false)
        .and_return(ls_remote_output)
    end

    def run_action(version)
      Fastlane::Actions::GetLatestReleaseBeforeVersionAction.run(repo_name: "purchases-ios-spm", version: version)
    end

    it 'returns the latest release before a snapshot version' do
      expect(run_action("5.93.0-SNAPSHOT")).to eq("5.92.1")
    end

    it 'returns the latest release before a stable version' do
      expect(run_action("5.93.0")).to eq("5.92.1")
    end

    it 'returns the previous patch release' do
      expect(run_action("5.92.1")).to eq("5.92.0")
    end

    it 'compares versions numerically' do
      expect(run_action("5.101.0-SNAPSHOT")).to eq("5.100.0")
    end

    it 'fails when there is no release before the version' do
      expect { run_action("5.91.0") }
        .to raise_error(FastlaneCore::Interface::FastlaneError, "No release of purchases-ios-spm found before 5.91.0")
    end
  end

  describe '#available_options' do
    it 'rejects repository URLs' do
      option = Fastlane::Actions::GetLatestReleaseBeforeVersionAction.available_options.find { |o| o.key == :repo_name }
      expect { option.verify!("https://github.com/RevenueCat/purchases-ios") }.to raise_error(FastlaneCore::Interface::FastlaneError)
      expect { option.verify!("RevenueCat/purchases-ios") }.to raise_error(FastlaneCore::Interface::FastlaneError)
      expect { option.verify!("purchases-ios") }.not_to raise_error
    end
  end
end
