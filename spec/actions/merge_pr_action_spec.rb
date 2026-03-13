describe Fastlane::Actions::MergePrAction do
  let(:github_token) { 'mock-github-token' }
  let(:repo_name) { 'purchases-ios' }
  let(:full_repo_name) { 'RevenueCat/purchases-ios' }
  let(:branch) { 'release/5.60.0' }
  let(:pr_number) { 42 }

  describe '#run' do
    it 'finds the PR and merges with defaults' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:find_open_pr_number)
        .with(
          repo_name: full_repo_name,
          branch: branch,
          base_branch: 'main',
          api_token: github_token
        )
        .and_return(pr_number)

      expect(Fastlane::Helper::GitHubHelper).to receive(:merge_pr)
        .with(
          repo_name: full_repo_name,
          pr_number: pr_number,
          api_token: github_token,
          merge_method: 'squash'
        )

      Fastlane::Actions::MergePrAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch
      )
    end

    it 'uses the current git branch when branch is not provided' do
      allow(Fastlane::Actions).to receive(:sh)
        .with("git rev-parse --abbrev-ref HEAD")
        .and_return("feature/my-branch\n")

      expect(Fastlane::Helper::GitHubHelper).to receive(:find_open_pr_number)
        .with(
          repo_name: full_repo_name,
          branch: 'feature/my-branch',
          base_branch: 'main',
          api_token: github_token
        )
        .and_return(pr_number)

      expect(Fastlane::Helper::GitHubHelper).to receive(:merge_pr)

      Fastlane::Actions::MergePrAction.run(
        github_token: github_token,
        repo_name: repo_name
      )
    end

    it 'supports a custom base branch' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:find_open_pr_number)
        .with(
          repo_name: full_repo_name,
          branch: branch,
          base_branch: 'develop',
          api_token: github_token
        )
        .and_return(pr_number)

      expect(Fastlane::Helper::GitHubHelper).to receive(:merge_pr)

      Fastlane::Actions::MergePrAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch,
        base_branch: 'develop'
      )
    end

    it 'passes custom merge_method to merge_pr' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:find_open_pr_number).and_return(pr_number)

      expect(Fastlane::Helper::GitHubHelper).to receive(:merge_pr)
        .with(
          repo_name: full_repo_name,
          pr_number: pr_number,
          api_token: github_token,
          merge_method: 'rebase'
        )

      Fastlane::Actions::MergePrAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch,
        merge_method: 'rebase'
      )
    end

    it 'propagates errors from find_open_pr_number' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:find_open_pr_number)
        .and_raise(FastlaneCore::Interface::FastlaneError.new)

      expect(Fastlane::Helper::GitHubHelper).not_to receive(:merge_pr)

      expect do
        Fastlane::Actions::MergePrAction.run(
          github_token: github_token,
          repo_name: repo_name,
          branch: branch
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError)
    end

    it 'propagates errors from merge_pr' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:find_open_pr_number).and_return(pr_number)

      expect(Fastlane::Helper::GitHubHelper).to receive(:merge_pr)
        .and_raise(StandardError.new("Failed to merge PR"))

      expect do
        Fastlane::Actions::MergePrAction.run(
          github_token: github_token,
          repo_name: repo_name,
          branch: branch
        )
      end.to raise_error(StandardError, /Failed to merge PR/)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::MergePrAction.available_options.size).to eq(5)
    end

    it 'has github_token option with GITHUB_TOKEN env_name' do
      option = Fastlane::Actions::MergePrAction.available_options.find { |o| o.key == :github_token }
      expect(option.env_name).to eq("GITHUB_TOKEN")
      expect(option.optional).to be false
    end

    it 'has branch option that is optional' do
      option = Fastlane::Actions::MergePrAction.available_options.find { |o| o.key == :branch }
      expect(option.optional).to be true
    end

    it 'has base_branch option defaulting to main' do
      option = Fastlane::Actions::MergePrAction.available_options.find { |o| o.key == :base_branch }
      expect(option.default_value).to eq("main")
      expect(option.optional).to be true
    end

    it 'has merge_method option defaulting to squash' do
      option = Fastlane::Actions::MergePrAction.available_options.find { |o| o.key == :merge_method }
      expect(option.default_value).to eq("squash")
      expect(option.optional).to be true
    end

    it 'rejects invalid merge_method values' do
      option = Fastlane::Actions::MergePrAction.available_options.find { |o| o.key == :merge_method }
      expect { option.verify!('YOLO') }.to raise_error(FastlaneCore::Interface::FastlaneError, /Invalid merge_method 'YOLO'/)
    end

    it 'accepts valid merge_method values' do
      option = Fastlane::Actions::MergePrAction.available_options.find { |o| o.key == :merge_method }
      %w[squash merge rebase].each do |method|
        expect { option.verify!(method) }.not_to raise_error
      end
    end
  end

  describe 'action metadata' do
    it 'has a description' do
      expect(Fastlane::Actions::MergePrAction.description).not_to be_empty
    end

    it 'has nil return value' do
      expect(Fastlane::Actions::MergePrAction.return_value).to be_nil
    end

    it 'supports all platforms' do
      expect(Fastlane::Actions::MergePrAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::MergePrAction.is_supported?(:android)).to be true
    end
  end
end
