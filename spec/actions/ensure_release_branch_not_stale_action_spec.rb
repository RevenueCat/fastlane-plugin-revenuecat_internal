describe Fastlane::Actions::EnsureReleaseBranchNotStaleAction do
  describe '#run' do
    it 'calls the helper with the appropriate parameters' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:ensure_release_branch_not_stale!)
        .with('release/1.2.3', 'abc123')
        .once

      Fastlane::Actions::EnsureReleaseBranchNotStaleAction.run(
        release_branch: 'release/1.2.3',
        cut_from_sha: 'abc123'
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::EnsureReleaseBranchNotStaleAction.available_options.size).to eq(2)
    end
  end
end
