describe Fastlane::Actions::CreateGithubReleaseAction do
  describe '#run' do
    let(:github_api_token) { 'fake-github-api-token' }
    let(:repo_name) { 'fake-repo-name' }
    let(:branch) { 'branch' }
    let(:release_version) { '1.12.0' }
    let(:changelog) { 'fake-changelog' }
    let(:changelog_latest_path) { './fake-changelog-latest-path/CHANGELOG.latest.md' }
    let(:upload_assets) { ['./path-to/upload-asset-1.txt', './path-to/upload-asset-2.rb'] }

    before(:each) do
      allow(File).to receive(:read).with(changelog_latest_path).and_return(changelog)
    end

    it 'calls all the appropriate methods with appropriate parameters' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_github_release)
        .with(release_version, changelog, upload_assets, repo_name, github_api_token)
        .once
      Fastlane::Actions::CreateGithubReleaseAction.run(
        version: release_version,
        repo_name: repo_name,
        github_api_token: github_api_token,
        changelog_latest_path: changelog_latest_path,
        upload_assets: upload_assets
      )
    end

    it 'fails if can not read CHANGELOG.latest.md file' do
      allow(File).to receive(:read).with(changelog_latest_path).and_raise(StandardError)
      expect do
        Fastlane::Actions::CreateGithubReleaseAction.run(
          version: release_version,
          repo_name: repo_name,
          github_api_token: github_api_token,
          changelog_latest_path: changelog_latest_path,
          upload_assets: upload_assets
        )
      end.to raise_exception(StandardError)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CreateGithubReleaseAction.available_options.size).to eq(5)
    end
  end
end
