describe Fastlane::Actions::CheckPrApprovedAction do
  let(:github_token) { 'mock-github-token' }
  let(:pr_url) { 'https://github.com/RevenueCat/purchases-ios/pull/42' }

  describe '#run' do
    it 'returns true when PR is approved by a user with write permission' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:pr_approved_by_org_member_with_write_permissions?)
        .with(pr_url, github_token)
        .and_return(true)

      result = Fastlane::Actions::CheckPrApprovedAction.run(
        github_token: github_token,
        pr_url: pr_url
      )

      expect(result).to be true
    end

    it 'returns false when PR has no qualifying approval' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:pr_approved_by_org_member_with_write_permissions?)
        .with(pr_url, github_token)
        .and_return(false)

      result = Fastlane::Actions::CheckPrApprovedAction.run(
        github_token: github_token,
        pr_url: pr_url
      )

      expect(result).to be false
    end

  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CheckPrApprovedAction.available_options.size).to eq(2)
    end

    it 'has github_token option with correct configuration' do
      option = Fastlane::Actions::CheckPrApprovedAction.available_options.find { |o| o.key == :github_token }
      expect(option.env_name).to eq("GITHUB_TOKEN")
      expect(option.optional).to be false
    end

    it 'has pr_url option backed by CIRCLE_PULL_REQUEST env var' do
      option = Fastlane::Actions::CheckPrApprovedAction.available_options.find { |o| o.key == :pr_url }
      expect(option.env_name).to eq("CIRCLE_PULL_REQUEST")
      expect(option.optional).to be false
    end
  end

  describe 'action metadata' do
    it 'has correct description' do
      expect(Fastlane::Actions::CheckPrApprovedAction.description)
        .to eq("Checks if the current PR is approved by an organization member with write permissions")
    end

    it 'has correct return value description' do
      expect(Fastlane::Actions::CheckPrApprovedAction.return_value)
        .to eq("Boolean indicating whether the PR is approved by an org member with write permissions")
    end

    it 'has correct authors' do
      expect(Fastlane::Actions::CheckPrApprovedAction.authors).to eq(["RevenueCat"])
    end

    it 'supports all platforms' do
      expect(Fastlane::Actions::CheckPrApprovedAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::CheckPrApprovedAction.is_supported?(:android)).to be true
    end
  end
end
