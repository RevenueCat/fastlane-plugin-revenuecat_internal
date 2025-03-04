describe Fastlane::Helper::GitHubHelper do
  describe '.get_pr_resp_items_for_sha' do
    let(:base_branch) { 'main' }
    let(:server_url) { 'https://api.github.com' }
    let(:http_method) { 'GET' }
    let(:hash) { 'a72c0435ecf71248f311900475e881cc07ac2eaf' }
    let(:github_token) { 'mock-github-token' }
    let(:get_feat_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_a72c0435ecf71248f311900475e881cc07ac2eaf.json") }
    end

    it 'returns items from response' do
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: "/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:#{base_branch}+SHA:#{hash}",
              http_method: http_method,
              body: {},
              api_token: github_token)
        .and_return(get_feat_commit_response)

      items = Fastlane::Helper::GitHubHelper.get_pr_resp_items_for_sha(
        hash,
        github_token,
        0,
        'mock-repo-name',
        'main'
      )

      github_response = get_feat_commit_response
      body = JSON.parse(github_response[:body])
      expected_items = body["items"]

      expect(items).not_to be_nil
      expect(items.length).to eq(1)
      expect(items).to eq(expected_items)
    end

    it 'sleeps if passing rate limit sleep' do
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: "/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:#{base_branch}+SHA:#{hash}",
              http_method: http_method,
              body: {},
              api_token: github_token)
        .and_return(get_feat_commit_response)

      expect_any_instance_of(Object).to receive(:sleep).with(1).exactly(1).times

      items = Fastlane::Helper::GitHubHelper.get_pr_resp_items_for_sha(
        hash,
        github_token,
        1,
        'mock-repo-name',
        'main'
      )
      expect(items).not_to be_nil
    end
  end

  describe '.get_commits_since_old_version' do
    let(:server_url) { 'https://api.github.com' }
    let(:http_method) { 'GET' }
    let(:last_commit_sha) { 'cfdd80f73d8c91121313d72227b4cbe283b57c1e' }
    let(:github_token) { 'mock-github-token' }
    let(:get_commits_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commits_since_last_release.json") }
    end

    it 'returns commits from response' do
      allow(Fastlane::Actions::LastGitCommitAction).to receive(:run)
        .and_return(commit_hash: last_commit_sha)
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: "/repos/RevenueCat/mock-repo-name/compare/1.11.0...#{last_commit_sha}",
              http_method: http_method,
              body: {},
              api_token: github_token)
        .and_return(get_commits_response)

      items = Fastlane::Helper::GitHubHelper.get_commits_since_old_version(github_token, '1.11.0', 'mock-repo-name')

      github_response = get_commits_response
      body = JSON.parse(github_response[:body])
      expected_items = body["commits"]

      expect(items).not_to be_nil
      expect(items.length).to eq(5)
      expected_items.each do |item|
        expect(expected_items.include?(item)).to be_truthy
      end
    end
  end

  describe '.create_github_release' do
    let(:server_url) { 'https://api.github.com' }
    let(:repo_name) { 'mock-repo-name' }
    let(:http_method) { 'POST' }
    let(:github_token) { 'mock-github-token' }
    let(:release_version) { '1.11.0' }
    let(:release_description) { 'Release description' }
    let(:commit_hash) { 'commit-hash' }
    let(:is_prerelease) { false }
    let(:is_latest_stable_release) { 'true' }
    let(:create_release_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/create_release_response.json") }
    end

    it 'creates a release' do
      expected_params = {
        server_url: server_url,
        path: "repos/RevenueCat/#{repo_name}/releases",
        http_method: http_method,
        body: {
          'tag_name' => release_version,
          'draft' => false,
          'prerelease' => is_prerelease,
          'generate_release_notes' => true,
          'make_latest' => is_latest_stable_release,
          'name' => release_version,
          'body' => release_description,
          'target_commitish' => commit_hash
        },
        api_token: github_token
      }

      expect(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(hash_including(expected_params))
        .and_return(create_release_response)

      Fastlane::Helper::GitHubHelper.create_github_release(
        repository_name: "RevenueCat/#{repo_name}",
        api_token: github_token,
        name: release_version,
        tag_name: release_version,
        description: release_description,
        commitish: commit_hash,
        is_draft: false,
        is_prerelease: is_prerelease,
        make_latest: is_latest_stable_release,
        is_generate_release_notes: true,
        server_url: 'https://api.github.com'
      )

      github_response = create_release_response
      body = JSON.parse(github_response[:body])

      expect(body).not_to be_nil
    end
  end
end
