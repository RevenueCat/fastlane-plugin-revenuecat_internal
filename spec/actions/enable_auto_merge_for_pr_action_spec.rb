describe Fastlane::Actions::EnableAutoMergeForPrAction do
  let(:github_token) { 'mock-github-token' }
  let(:repo_name) { 'RevenueCat/purchases-ios' }
  let(:branch) { 'release/5.60.0' }
  let(:pr_number) { 42 }
  let(:pr_title) { 'Release/5.60.0' }

  let(:pr_list_response) do
    {
      body: [{ "number" => pr_number, "title" => pr_title }].to_json
    }
  end

  let(:empty_pr_list_response) do
    {
      body: [].to_json
    }
  end

  describe '#run' do
    it 'finds the PR by branch and enables auto-merge' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: "https://api.github.com",
          http_method: "GET",
          path: "/repos/#{repo_name}/pulls?head=RevenueCat:#{branch}&base=main&state=open",
          api_token: github_token
        )
        .and_return(pr_list_response)

      expect(Fastlane::Helper::GitHubHelper).to receive(:enable_auto_merge)
        .with(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: github_token,
          merge_method: 'SQUASH'
        )

      Fastlane::Actions::EnableAutoMergeForPrAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch
      )
    end

    it 'uses the current git branch when branch is not provided' do
      allow(Fastlane::Actions).to receive(:sh)
        .with("git rev-parse --abbrev-ref HEAD")
        .and_return("feature/my-branch\n")

      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: "https://api.github.com",
          http_method: "GET",
          path: "/repos/#{repo_name}/pulls?head=RevenueCat:feature/my-branch&base=main&state=open",
          api_token: github_token
        )
        .and_return(pr_list_response)

      expect(Fastlane::Helper::GitHubHelper).to receive(:enable_auto_merge)

      Fastlane::Actions::EnableAutoMergeForPrAction.run(
        github_token: github_token,
        repo_name: repo_name
      )
    end

    it 'supports a custom base branch' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: "https://api.github.com",
          http_method: "GET",
          path: "/repos/#{repo_name}/pulls?head=RevenueCat:#{branch}&base=develop&state=open",
          api_token: github_token
        )
        .and_return(pr_list_response)

      expect(Fastlane::Helper::GitHubHelper).to receive(:enable_auto_merge)

      Fastlane::Actions::EnableAutoMergeForPrAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch,
        base_branch: 'develop'
      )
    end

    it 'passes custom merge_method to enable_auto_merge' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_return(pr_list_response)

      expect(Fastlane::Helper::GitHubHelper).to receive(:enable_auto_merge)
        .with(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: github_token,
          merge_method: 'SQUASH'
        )

      Fastlane::Actions::EnableAutoMergeForPrAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch,
        merge_method: 'SQUASH'
      )
    end

    it 'raises an error when no open PR is found' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_return(empty_pr_list_response)

      expect(Fastlane::Helper::GitHubHelper).not_to receive(:enable_auto_merge)

      expect do
        Fastlane::Actions::EnableAutoMergeForPrAction.run(
          github_token: github_token,
          repo_name: repo_name,
          branch: branch
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /No open PR found from #{Regexp.escape(branch)} into main/)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::EnableAutoMergeForPrAction.available_options.size).to eq(5)
    end

    it 'has github_token option with GITHUB_TOKEN env_name' do
      option = Fastlane::Actions::EnableAutoMergeForPrAction.available_options.find { |o| o.key == :github_token }
      expect(option.env_name).to eq("GITHUB_TOKEN")
      expect(option.optional).to be false
    end

    it 'has branch option that is optional' do
      option = Fastlane::Actions::EnableAutoMergeForPrAction.available_options.find { |o| o.key == :branch }
      expect(option.optional).to be true
    end

    it 'has base_branch option defaulting to main' do
      option = Fastlane::Actions::EnableAutoMergeForPrAction.available_options.find { |o| o.key == :base_branch }
      expect(option.default_value).to eq("main")
      expect(option.optional).to be true
    end

    it 'has merge_method option defaulting to SQUASH' do
      option = Fastlane::Actions::EnableAutoMergeForPrAction.available_options.find { |o| o.key == :merge_method }
      expect(option.default_value).to eq("SQUASH")
      expect(option.optional).to be true
    end
  end

  describe 'action metadata' do
    it 'has a description' do
      expect(Fastlane::Actions::EnableAutoMergeForPrAction.description).not_to be_empty
    end

    it 'has nil return value' do
      expect(Fastlane::Actions::EnableAutoMergeForPrAction.return_value).to be_nil
    end

    it 'supports all platforms' do
      expect(Fastlane::Actions::EnableAutoMergeForPrAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::EnableAutoMergeForPrAction.is_supported?(:android)).to be true
    end
  end
end
