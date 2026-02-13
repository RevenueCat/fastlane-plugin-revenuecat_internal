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
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
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
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
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
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
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

      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
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

  describe '.github_api_call_with_retry' do
    let(:api_params) do
      {
        server_url: 'https://api.github.com',
        path: '/test/path',
        http_method: 'GET',
        body: {},
        api_token: 'test-token'
      }
    end
    let(:successful_response) { { body: '{"success": true}' } }

    context 'when API call succeeds on first try' do
      it 'returns the response without retries' do
        expect(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(api_params)
          .once
          .and_return(successful_response)

        result = Fastlane::Helper::GitHubHelper.github_api_call_with_retry(**api_params)
        expect(result).to eq(successful_response)
      end
    end

    context 'when API call hits rate limit but succeeds on retry' do
      it 'retries and succeeds on second attempt' do
        rate_limit_error = StandardError.new('GitHub responded with 403 rate limit exceeded')

        expect(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(api_params)
          .once
          .and_raise(rate_limit_error)

        expect(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(api_params)
          .once
          .and_return(successful_response)

        allow_any_instance_of(Object).to receive(:sleep)

        result = Fastlane::Helper::GitHubHelper.github_api_call_with_retry(**api_params)
        expect(result).to eq(successful_response)
      end
    end

    context 'when API call exhausts all retries' do
      it 'raises user error after max retries' do
        rate_limit_error = StandardError.new('GitHub responded with 403 rate limit exceeded')

        expect(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(api_params)
          .exactly(4).times # Initial call + 3 retries
          .and_raise(rate_limit_error)

        # Allow sleep to be called (we just care that retries happen and final error is raised)
        allow_any_instance_of(Object).to receive(:sleep)

        expect do
          Fastlane::Helper::GitHubHelper.github_api_call_with_retry(**api_params)
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /GitHub rate limit exceeded and max retries \(3\) reached/)
      end
    end

    context 'when API call fails with non-rate-limit error' do
      it 'raises the error immediately without retries' do
        non_rate_limit_error = StandardError.new('Some other error')

        expect(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(api_params)
          .once
          .and_raise(non_rate_limit_error)

        expect_any_instance_of(Object).not_to receive(:sleep)

        expect do
          Fastlane::Helper::GitHubHelper.github_api_call_with_retry(**api_params)
        end.to raise_error(non_rate_limit_error)
      end
    end

    context 'when API call fails with 403 but not rate limit related' do
      it 'raises the error immediately without retries' do
        auth_error = StandardError.new('GitHub responded with 403 forbidden access')

        expect(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(api_params)
          .once
          .and_raise(auth_error)

        expect_any_instance_of(Object).not_to receive(:sleep)

        expect do
          Fastlane::Helper::GitHubHelper.github_api_call_with_retry(**api_params)
        end.to raise_error(auth_error)
      end
    end

    context 'with custom max_retries' do
      it 'respects the custom retry limit' do
        rate_limit_error = StandardError.new('GitHub responded with 403 rate limit exceeded')

        expect(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(api_params)
          .exactly(2).times # Initial call + 1 retry
          .and_raise(rate_limit_error)

        allow_any_instance_of(Object).to receive(:sleep)

        expect do
          Fastlane::Helper::GitHubHelper.github_api_call_with_retry(max_retries: 1, **api_params)
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /GitHub rate limit exceeded and max retries \(1\) reached/)
      end
    end
  end

  describe '.enable_auto_merge' do
    let(:repo_name) { 'RevenueCat/mock-repo-name' }
    let(:pr_number) { 42 }
    let(:api_token) { 'mock-github-token' }
    let(:node_id) { 'PR_kwDOFake123' }

    it 'enables auto-merge with SQUASH merge method' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: 'https://api.github.com',
          http_method: 'GET',
          path: "/repos/#{repo_name}/pulls/#{pr_number}",
          api_token: api_token
        )
        .and_return({ json: { 'node_id' => node_id } })

      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: 'https://api.github.com',
          http_method: 'POST',
          path: '/graphql',
          body: { query: "mutation { enablePullRequestAutoMerge(input: {pullRequestId: \"#{node_id}\", mergeMethod: SQUASH}) { pullRequest { autoMergeRequest { enabledAt } } } }" },
          api_token: api_token
        )
        .and_return({ json: {} })

      Fastlane::Helper::GitHubHelper.enable_auto_merge(
        repo_name: repo_name,
        pr_number: pr_number,
        api_token: api_token
      )
    end

    it 'supports custom merge method' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: 'https://api.github.com',
          http_method: 'GET',
          path: "/repos/#{repo_name}/pulls/#{pr_number}",
          api_token: api_token
        )
        .and_return({ json: { 'node_id' => node_id } })

      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: 'https://api.github.com',
          http_method: 'POST',
          path: '/graphql',
          body: { query: "mutation { enablePullRequestAutoMerge(input: {pullRequestId: \"#{node_id}\", mergeMethod: MERGE}) { pullRequest { autoMergeRequest { enabledAt } } } }" },
          api_token: api_token
        )
        .and_return({ json: {} })

      Fastlane::Helper::GitHubHelper.enable_auto_merge(
        repo_name: repo_name,
        pr_number: pr_number,
        api_token: api_token,
        merge_method: 'MERGE'
      )
    end

    it 'logs error and returns if node_id is nil' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: 'https://api.github.com',
          http_method: 'GET',
          path: "/repos/#{repo_name}/pulls/#{pr_number}",
          api_token: api_token
        )
        .and_return({ json: { 'node_id' => nil } })

      expect(FastlaneCore::UI).to receive(:error)
        .with("Could not retrieve node_id for PR ##{pr_number}. Auto-merge was not enabled.")

      # Should not attempt the GraphQL call
      expect(Fastlane::Helper::GitHubHelper).not_to receive(:github_api_call_with_retry)
        .with(hash_including(path: '/graphql'))

      Fastlane::Helper::GitHubHelper.enable_auto_merge(
        repo_name: repo_name,
        pr_number: pr_number,
        api_token: api_token
      )
    end

    it 'logs error and returns if GraphQL response contains errors' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: 'https://api.github.com',
          http_method: 'GET',
          path: "/repos/#{repo_name}/pulls/#{pr_number}",
          api_token: api_token
        )
        .and_return({ json: { 'node_id' => node_id } })

      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: 'https://api.github.com',
          http_method: 'POST',
          path: '/graphql',
          body: { query: "mutation { enablePullRequestAutoMerge(input: {pullRequestId: \"#{node_id}\", mergeMethod: SQUASH}) { pullRequest { autoMergeRequest { enabledAt } } } }" },
          api_token: api_token
        )
        .and_return({ json: { 'errors' => [{ 'message' => 'Pull request Auto merge is not allowed for this repository' }] } })

      expect(FastlaneCore::UI).to receive(:error)
        .with("Failed to enable auto-merge for PR ##{pr_number}: Pull request Auto merge is not allowed for this repository")
      expect(FastlaneCore::UI).not_to receive(:success)

      Fastlane::Helper::GitHubHelper.enable_auto_merge(
        repo_name: repo_name,
        pr_number: pr_number,
        api_token: api_token
      )
    end
  end
end
