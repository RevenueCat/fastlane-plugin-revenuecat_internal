describe Fastlane::Actions::UpdatePrBranchAction do
  let(:github_token) { 'mock-github-token' }
  let(:repo_name) { 'purchases-ios' }
  let(:full_repo_name) { 'RevenueCat/purchases-ios' }
  let(:branch) { 'release/5.60.0' }
  let(:pr_number) { 42 }

  describe '#run' do
    it 'finds the PR without base_branch and updates the branch' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:find_open_pr_number)
        .with(
          repo_name: full_repo_name,
          branch: branch,
          api_token: github_token
        )
        .and_return(pr_number)

      expect(Fastlane::Helper::GitHubHelper).to receive(:update_pr_branch)
        .with(
          repo_name: full_repo_name,
          pr_number: pr_number,
          api_token: github_token
        )

      Fastlane::Actions::UpdatePrBranchAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch
      )
    end

    it 'uses the current git branch when branch is not provided' do
      allow(Fastlane::Actions).to receive(:sh)
        .with("git rev-parse --abbrev-ref HEAD")
        .and_return("feature/my-branch\n")

      expect(Fastlane::Helper::GitHubHelper).to receive(:find_unique_open_pr_number)
        .with(
          repo_name: full_repo_name,
          branch: 'feature/my-branch',
          api_token: github_token
        )
        .and_return(pr_number)

      expect(Fastlane::Helper::GitHubHelper).to receive(:update_pr_branch)

      Fastlane::Actions::UpdatePrBranchAction.run(
        github_token: github_token,
        repo_name: repo_name
      )
    end

    it 'passes base_branch to find_unique_open_pr_number when provided' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:find_unique_open_pr_number)
        .with(
          repo_name: full_repo_name,
          branch: branch,
          base_branch: 'develop',
          api_token: github_token
        )
        .and_return(pr_number)

      expect(Fastlane::Helper::GitHubHelper).to receive(:update_pr_branch)

      Fastlane::Actions::UpdatePrBranchAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch,
        base_branch: 'develop'
      )
    end

    it 'propagates errors from find_unique_open_pr_number' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:find_unique_open_pr_number)
        .and_raise(FastlaneCore::Interface::FastlaneError.new)

      expect(Fastlane::Helper::GitHubHelper).not_to receive(:update_pr_branch)

      expect do
        Fastlane::Actions::UpdatePrBranchAction.run(
          github_token: github_token,
          repo_name: repo_name,
          branch: branch
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError)
    end

    it 'propagates errors from update_pr_branch' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:find_unique_open_pr_number).and_return(pr_number)

      expect(Fastlane::Helper::GitHubHelper).to receive(:update_pr_branch)
        .and_raise(StandardError.new("Failed to update branch"))

      expect do
        Fastlane::Actions::UpdatePrBranchAction.run(
          github_token: github_token,
          repo_name: repo_name,
          branch: branch
        )
      end.to raise_error(StandardError, /Failed to update branch/)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::UpdatePrBranchAction.available_options.size).to eq(4)
    end

    it 'has github_token option with GITHUB_TOKEN env_name' do
      option = Fastlane::Actions::UpdatePrBranchAction.available_options.find { |o| o.key == :github_token }
      expect(option.env_name).to eq("GITHUB_TOKEN")
      expect(option.optional).to be false
    end

    it 'has branch option that is optional' do
      option = Fastlane::Actions::UpdatePrBranchAction.available_options.find { |o| o.key == :branch }
      expect(option.optional).to be true
    end

    it 'has base_branch option that is optional with no default' do
      option = Fastlane::Actions::UpdatePrBranchAction.available_options.find { |o| o.key == :base_branch }
      expect(option.default_value).to be_nil
      expect(option.optional).to be true
    end
  end

  describe 'action metadata' do
    it 'has a description' do
      expect(Fastlane::Actions::UpdatePrBranchAction.description).not_to be_empty
    end

    it 'has nil return value' do
      expect(Fastlane::Actions::UpdatePrBranchAction.return_value).to be_nil
    end

    it 'supports all platforms' do
      expect(Fastlane::Actions::UpdatePrBranchAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::UpdatePrBranchAction.is_supported?(:android)).to be true
    end
  end
end
