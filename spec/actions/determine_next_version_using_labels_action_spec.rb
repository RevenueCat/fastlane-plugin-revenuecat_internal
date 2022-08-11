describe Fastlane::Actions::DetermineNextVersionUsingLabelsAction do
  describe '#run' do
    let(:mock_repo_name) { 'mock-repo-name' }
    let(:mock_github_token) { 'mock-github-token' }
    let(:new_version) { '1.13.0' }

    it 'calls all the appropriate methods with appropriate parameters' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:determine_next_version_using_labels)
        .with(mock_repo_name, mock_github_token, 3)
        .and_return(new_version)
        .once

      Fastlane::Actions::DetermineNextVersionUsingLabelsAction.run(
        repo_name: mock_repo_name,
        github_token: mock_github_token,
        github_rate_limit: 3
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::DetermineNextVersionUsingLabelsAction.available_options.size).to eq(3)
    end
  end
end
