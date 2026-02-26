require 'uri'

describe Fastlane::Actions::EnableAutoMergeForPrAction do
  let(:github_token) { 'mock-github-token' }
  let(:repo_name) { 'purchases-ios' }
  let(:full_repo_name) { 'RevenueCat/purchases-ios' }
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

  def expected_path(head_branch, base_branch = 'main')
    query = URI.encode_www_form(head: "RevenueCat:#{head_branch}", base: base_branch, state: "open")
    "/repos/#{full_repo_name}/pulls?#{query}"
  end

  describe '#run' do
    it 'finds the PR by branch and enables auto-merge' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: "https://api.github.com",
          http_method: "GET",
          path: expected_path(branch),
          api_token: github_token
        )
        .and_return(pr_list_response)

      expect(Fastlane::Helper::GitHubHelper).to receive(:enable_auto_merge)
        .with(
          repo_name: full_repo_name,
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
          path: expected_path('feature/my-branch'),
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
          path: expected_path(branch, 'develop'),
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
          repo_name: full_repo_name,
          pr_number: pr_number,
          api_token: github_token,
          merge_method: 'REBASE'
        )

      Fastlane::Actions::EnableAutoMergeForPrAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch,
        merge_method: 'REBASE'
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

    it 'logs warning and picks last PR when multiple PRs match' do
      newer_pr = { "number" => 42, "title" => "New PR" }
      older_pr = { "number" => 10, "title" => "Old PR" }
      multi_pr_response = { body: [newer_pr, older_pr].to_json }

      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_return(multi_pr_response)

      expect(FastlaneCore::UI).to receive(:important)
        .with("Found 2 open PRs from #{branch} into main, using the most recent one")

      expect(Fastlane::Helper::GitHubHelper).to receive(:enable_auto_merge)
        .with(
          repo_name: full_repo_name,
          pr_number: 42,
          api_token: github_token,
          merge_method: 'SQUASH'
        )

      Fastlane::Actions::EnableAutoMergeForPrAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: branch
      )
    end

    it 'URL-encodes branch names with special characters' do
      special_branch = 'feature/foo&bar#1'

      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: "https://api.github.com",
          http_method: "GET",
          path: expected_path(special_branch),
          api_token: github_token
        )
        .and_return(pr_list_response)

      expect(Fastlane::Helper::GitHubHelper).to receive(:enable_auto_merge)

      Fastlane::Actions::EnableAutoMergeForPrAction.run(
        github_token: github_token,
        repo_name: repo_name,
        branch: special_branch
      )
    end

    it 'propagates errors raised by enable_auto_merge' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_return(pr_list_response)

      expect(Fastlane::Helper::GitHubHelper).to receive(:enable_auto_merge)
        .and_raise(StandardError.new("Failed to enable auto-merge for PR ##{pr_number}: something went wrong"))

      expect do
        Fastlane::Actions::EnableAutoMergeForPrAction.run(
          github_token: github_token,
          repo_name: repo_name,
          branch: branch
        )
      end.to raise_error(StandardError, /Failed to enable auto-merge/)
    end

    it 'propagates network errors from the API call' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_raise(StandardError.new("Connection refused"))

      expect(Fastlane::Helper::GitHubHelper).not_to receive(:enable_auto_merge)

      expect do
        Fastlane::Actions::EnableAutoMergeForPrAction.run(
          github_token: github_token,
          repo_name: repo_name,
          branch: branch
        )
      end.to raise_error(StandardError, /Connection refused/)
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

    it 'rejects invalid merge_method values' do
      option = Fastlane::Actions::EnableAutoMergeForPrAction.available_options.find { |o| o.key == :merge_method }
      expect { option.verify!('YOLO') }.to raise_error(FastlaneCore::Interface::FastlaneError, /Invalid merge_method 'YOLO'/)
    end

    it 'accepts valid merge_method values' do
      option = Fastlane::Actions::EnableAutoMergeForPrAction.available_options.find { |o| o.key == :merge_method }
      %w[SQUASH MERGE REBASE].each do |method|
        expect { option.verify!(method) }.not_to raise_error
      end
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
