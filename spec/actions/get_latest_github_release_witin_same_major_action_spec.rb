describe Fastlane::Actions::GetLatestGithubReleaseWithinSameMajorAction do
  describe '#run' do
    let(:repo_name) { 'purchases-ios' }
    let(:get_releases_purchases_ios_response) do
      { json: JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_files/get_releases_purchases_ios.json")) }
    end

    before(:each) do
      allow(Fastlane::Actions::GithubApiAction).to receive(:run).with(
        server_url: "https://api.github.com",
        http_method: 'GET',
        path: "repos/RevenueCat/purchases-ios/releases",
        error_handlers: anything
      ).and_return(get_releases_purchases_ios_response).once
    end

    it 'returns highest version within same major, but not highest version' do
      latest_version = Fastlane::Actions::GetLatestGithubReleaseWithinSameMajorAction.run(
        repo_name: repo_name,
        current_version: '4.7.0'
      )
      expect(latest_version).to eq('4.9.1')
    end

    it 'returns highest version within same major, if highest version available' do
      latest_version = Fastlane::Actions::GetLatestGithubReleaseWithinSameMajorAction.run(
        repo_name: repo_name,
        current_version: '5.9.0'
      )
      expect(latest_version).to eq('5.10.0')
    end

    it 'fails if no version within same major' do
      expect do
        Fastlane::Actions::GetLatestGithubReleaseWithinSameMajorAction.run(
          repo_name: repo_name,
          current_version: '6.0.0'
        )
      end.to raise_exception(StandardError)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::GetLatestGithubReleaseWithinSameMajorAction.available_options.size).to eq(2)
    end
  end
end
