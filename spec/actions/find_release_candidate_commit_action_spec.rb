describe Fastlane::Actions::FindReleaseCandidateCommitAction do
  describe '#run' do
    it 'calls the helper with the appropriate parameters' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:find_candidate_commit)
        .with('mock-repo-name', 'mock-github-token', skip_label: 'upload:skip', lookback: 30)
        .and_return('abc123')
        .once

      sha = Fastlane::Actions::FindReleaseCandidateCommitAction.run(
        repo_name: 'mock-repo-name',
        github_token: 'mock-github-token',
        skip_label: 'upload:skip',
        lookback: 30
      )
      expect(sha).to eq('abc123')
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::FindReleaseCandidateCommitAction.available_options.size).to eq(4)
    end

    it 'has the documented defaults' do
      options = Fastlane::Actions::FindReleaseCandidateCommitAction.available_options
      defaults = options.to_h { |option| [option.key, option.default_value] }
      expect(defaults[:skip_label]).to eq('upload:skip')
      expect(defaults[:lookback]).to eq(30)
    end
  end
end
