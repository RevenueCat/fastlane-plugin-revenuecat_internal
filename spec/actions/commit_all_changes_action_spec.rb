describe Fastlane::Actions::CommitAllChangesAction do
  describe '#run' do
    it 'calls appropriate helper method with expected parameters' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_all_changes).with('fake-commit-message').once
      Fastlane::Actions::CommitAllChangesAction.run(
        commit_message: 'fake-commit-message'
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CommitAllChangesAction.available_options.size).to eq(1)
    end
  end
end
