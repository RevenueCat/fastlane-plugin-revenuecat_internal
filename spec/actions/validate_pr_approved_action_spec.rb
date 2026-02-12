describe Fastlane::Actions::ValidatePrApprovedAction do
  let(:github_token) { 'mock-github-token' }
  let(:pr_url) { 'https://github.com/RevenueCat/purchases-ios/pull/42' }

  describe '#run' do
    it 'succeeds when PR is approved by a user with write permission' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:pr_approved_by_org_member_with_write_permissions?)
        .with(pr_url, github_token)
        .and_return(true)

      expect(Fastlane::UI).to receive(:success)
        .with("PR has been approved by an organization member with write permissions")

      Fastlane::Actions::ValidatePrApprovedAction.run(
        github_token: github_token,
        pr_url: pr_url
      )
    end

    it 'raises an error when PR has no qualifying approval' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:pr_approved_by_org_member_with_write_permissions?)
        .with(pr_url, github_token)
        .and_return(false)

      expect do
        Fastlane::Actions::ValidatePrApprovedAction.run(
          github_token: github_token,
          pr_url: pr_url
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /PR has not been approved/)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.available_options.size).to eq(2)
    end

    it 'has github_token option with correct configuration' do
      option = Fastlane::Actions::ValidatePrApprovedAction.available_options.find { |o| o.key == :github_token }
      expect(option.env_name).to eq("GITHUB_TOKEN")
      expect(option.optional).to be false
    end

    it 'has pr_url option backed by CIRCLE_PULL_REQUEST env var' do
      option = Fastlane::Actions::ValidatePrApprovedAction.available_options.find { |o| o.key == :pr_url }
      expect(option.env_name).to eq("CIRCLE_PULL_REQUEST")
      expect(option.optional).to be false
    end
  end

  describe 'action metadata' do
    it 'has correct description' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.description)
        .to eq("Validates that the current PR is approved by an organization member with write permissions")
    end

    it 'has nil return value' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.return_value).to be_nil
    end

    it 'has correct authors' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.authors).to eq(["RevenueCat"])
    end

    it 'supports all platforms' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::ValidatePrApprovedAction.is_supported?(:android)).to be true
    end
  end
end
