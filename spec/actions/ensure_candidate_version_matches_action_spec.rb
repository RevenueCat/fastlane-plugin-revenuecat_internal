describe Fastlane::Actions::EnsureCandidateVersionMatchesAction do
  describe '#run' do
    it 'calls the helper with the appropriate parameters' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:ensure_candidate_version_matches!)
        .with('abc123', '1.2.3')
        .once

      Fastlane::Actions::EnsureCandidateVersionMatchesAction.run(
        sha: 'abc123',
        version: '1.2.3'
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::EnsureCandidateVersionMatchesAction.available_options.size).to eq(2)
    end
  end
end
