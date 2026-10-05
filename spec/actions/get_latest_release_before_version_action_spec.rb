describe Fastlane::Actions::GetLatestReleaseBeforeVersionAction do
  describe '#run' do
    let(:releases) do
      [
        { "tag_name" => "5.100.0" },
        { "tag_name" => "5.93.0" },
        { "tag_name" => "5.93.0-beta.1", "prerelease" => true },
        { "tag_name" => "5.92.3", "draft" => true },
        { "tag_name" => "5.92.2", "prerelease" => true },
        { "tag_name" => "5.92.1" },
        { "tag_name" => "not-a-version" },
        { "tag_name" => "5.92.0" },
        { "tag_name" => "5.91.0" }
      ]
    end

    before do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(server_url: "https://api.github.com",
              http_method: "GET",
              path: "/repos/RevenueCat/purchases-ios/releases?per_page=100",
              body: {},
              api_token: "mock-github-token")
        .and_return({ json: releases })
    end

    def run_action(version)
      Fastlane::Actions::GetLatestReleaseBeforeVersionAction.run(
        repo_name: "purchases-ios",
        version: version,
        github_token: "mock-github-token"
      )
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

    it 'ignores drafts and prereleases' do
      expect(run_action("5.92.4")).to eq("5.92.1")
    end

    it 'fails when there is no release before the version' do
      expect { run_action("5.91.0") }
        .to raise_error(FastlaneCore::Interface::FastlaneError, "No release of purchases-ios found before 5.91.0")
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
