describe Fastlane::Actions::CreateOrCheckoutBranchAction do
  describe '#run' do
    it 'calls appropriate helper method with expected parameters' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_or_checkout_branch).with('test-branch').once
      Fastlane::Actions::CreateOrCheckoutBranchAction.run(
        branch_name: 'test-branch'
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CreateOrCheckoutBranchAction.available_options.size).to eq(1)
    end
  end
end
