describe Fastlane::Actions::CommitCurrentChangesAction do
  describe '#run' do
    it 'calls appropriate actions with expected parameters' do
      expect(Fastlane::Actions).to receive(:sh).with('git add -u').once
      expect(Fastlane::Actions).to receive(:sh).with("git commit -m 'fake-commit-message'").once
      Fastlane::Actions::CommitCurrentChangesAction.run(
        commit_message: 'fake-commit-message'
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CommitCurrentChangesAction.available_options.size).to eq(1)
    end
  end
end
