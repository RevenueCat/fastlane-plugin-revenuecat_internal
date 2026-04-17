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

  describe '.pr_approved_by_org_member_with_write_permissions?' do
    let(:github_token) { 'mock-github-token' }
    let(:pr_url) { 'https://github.com/RevenueCat/purchases-ios/pull/42' }

    it 'returns true when an approved reviewer has write permission' do
      reviews = [
        { 'user' => { 'login' => 'dev1' }, 'state' => 'APPROVED' }
      ]
      permission_resp = { 'permission' => 'write' }

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)
      allow(Fastlane::Helper::GitHubHelper).to receive(:get_collaborator_permission)
        .with('RevenueCat', 'purchases-ios', 'dev1', github_token)
        .and_return(permission_resp)

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be true
    end

    it 'returns true when an approved reviewer has admin permission' do
      reviews = [
        { 'user' => { 'login' => 'admin1' }, 'state' => 'APPROVED' }
      ]
      permission_resp = { 'permission' => 'admin' }

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)
      allow(Fastlane::Helper::GitHubHelper).to receive(:get_collaborator_permission)
        .with('RevenueCat', 'purchases-ios', 'admin1', github_token)
        .and_return(permission_resp)

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be true
    end

    it 'returns false when the only approved reviewer has read permission' do
      reviews = [
        { 'user' => { 'login' => 'reader1' }, 'state' => 'APPROVED' }
      ]
      permission_resp = { 'permission' => 'read' }

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)
      allow(Fastlane::Helper::GitHubHelper).to receive(:get_collaborator_permission)
        .with('RevenueCat', 'purchases-ios', 'reader1', github_token)
        .and_return(permission_resp)

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be false
    end

    it 'returns false when there are no reviews' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return([])

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be false
    end

    it 'returns false when all reviews are CHANGES_REQUESTED' do
      reviews = [
        { 'user' => { 'login' => 'dev1' }, 'state' => 'CHANGES_REQUESTED' }
      ]

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be false
    end

    it 'uses latest decisive review state per user (approval overridden by changes requested)' do
      reviews = [
        { 'user' => { 'login' => 'dev1' }, 'state' => 'APPROVED' },
        { 'user' => { 'login' => 'dev1' }, 'state' => 'CHANGES_REQUESTED' }
      ]

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be false
    end

    it 'ignores COMMENTED reviews when determining latest state' do
      reviews = [
        { 'user' => { 'login' => 'dev1' }, 'state' => 'APPROVED' },
        { 'user' => { 'login' => 'dev1' }, 'state' => 'COMMENTED' }
      ]
      permission_resp = { 'permission' => 'write' }

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)
      allow(Fastlane::Helper::GitHubHelper).to receive(:get_collaborator_permission)
        .with('RevenueCat', 'purchases-ios', 'dev1', github_token)
        .and_return(permission_resp)

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be true
    end

    it 'returns true when at least one of multiple reviewers is an approved writer' do
      reviews = [
        { 'user' => { 'login' => 'reader1' }, 'state' => 'APPROVED' },
        { 'user' => { 'login' => 'writer1' }, 'state' => 'APPROVED' }
      ]

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)
      allow(Fastlane::Helper::GitHubHelper).to receive(:get_collaborator_permission)
        .with('RevenueCat', 'purchases-ios', 'reader1', github_token)
        .and_return({ 'permission' => 'read' })
      allow(Fastlane::Helper::GitHubHelper).to receive(:get_collaborator_permission)
        .with('RevenueCat', 'purchases-ios', 'writer1', github_token)
        .and_return({ 'permission' => 'write' })

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be true
    end

    it 'returns false when approval is dismissed' do
      reviews = [
        { 'user' => { 'login' => 'dev1' }, 'state' => 'APPROVED' },
        { 'user' => { 'login' => 'dev1' }, 'state' => 'DISMISSED' }
      ]

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be false
    end

    it 'returns true when re-approved after changes requested' do
      reviews = [
        { 'user' => { 'login' => 'dev1' }, 'state' => 'CHANGES_REQUESTED' },
        { 'user' => { 'login' => 'dev1' }, 'state' => 'APPROVED' }
      ]
      permission_resp = { 'permission' => 'write' }

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)
      allow(Fastlane::Helper::GitHubHelper).to receive(:get_collaborator_permission)
        .with('RevenueCat', 'purchases-ios', 'dev1', github_token)
        .and_return(permission_resp)

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be true
    end

    it 'returns false gracefully when collaborator permission check fails (e.g. non-collaborator 404)' do
      reviews = [
        { 'user' => { 'login' => 'outsider1' }, 'state' => 'APPROVED' }
      ]

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(path: "/repos/RevenueCat/purchases-ios/collaborators/outsider1/permission"))
        .and_raise(StandardError.new("404 Not Found"))

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be false
    end

    it 'returns true when an approved reviewer has maintain permission' do
      reviews = [
        { 'user' => { 'login' => 'maintainer1' }, 'state' => 'APPROVED' }
      ]
      permission_resp = { 'permission' => 'maintain' }

      allow(Fastlane::Helper::GitHubHelper).to receive(:get_pr_reviews)
        .with('RevenueCat', 'purchases-ios', '42', github_token)
        .and_return(reviews)
      allow(Fastlane::Helper::GitHubHelper).to receive(:get_collaborator_permission)
        .with('RevenueCat', 'purchases-ios', 'maintainer1', github_token)
        .and_return(permission_resp)

      result = Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?(pr_url, github_token)
      expect(result).to be true
    end

    it 'raises an error for an invalid PR URL' do
      expect do
        Fastlane::Helper::GitHubHelper.pr_approved_by_org_member_with_write_permissions?('not-a-url', github_token)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Could not parse PR URL/)
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

  describe '.find_unique_open_pr_number' do
    let(:repo_name) { 'RevenueCat/mock-repo-name' }
    let(:api_token) { 'mock-github-token' }
    let(:branch) { 'release/5.60.0' }
    let(:base_branch) { 'main' }

    def expected_path_with_base(head_branch, target_base)
      query = URI.encode_www_form(head: "RevenueCat:#{head_branch}", state: "open", base: target_base)
      "/repos/#{repo_name}/pulls?#{query}"
    end

    def expected_path_without_base(head_branch)
      query = URI.encode_www_form(head: "RevenueCat:#{head_branch}", state: "open")
      "/repos/#{repo_name}/pulls?#{query}"
    end

    context 'with base_branch specified' do
      it 'returns the PR number for a single matching PR' do
        pr_response = { body: [{ "number" => 42, "title" => "Release PR" }].to_json }

        expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
          .with(
            server_url: 'https://api.github.com',
            http_method: 'GET',
            path: expected_path_with_base(branch, base_branch),
            api_token: api_token
          )
          .and_return(pr_response)

        result = Fastlane::Helper::GitHubHelper.find_unique_open_pr_number(
          repo_name: repo_name,
          branch: branch,
          base_branch: base_branch,
          api_token: api_token
        )

        expect(result).to eq(42)
      end

      it 'raises error when no open PR is found' do
        empty_response = { body: [].to_json }

        expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
          .and_return(empty_response)

        expect do
          Fastlane::Helper::GitHubHelper.find_unique_open_pr_number(
            repo_name: repo_name,
            branch: branch,
            base_branch: base_branch,
            api_token: api_token
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /No open PR found from #{Regexp.escape(branch)} into #{base_branch}/)
      end

      it 'picks the first (most recent) PR and warns when multiple match' do
        newer_pr = { "number" => 42, "title" => "New PR" }
        older_pr = { "number" => 10, "title" => "Old PR" }
        multi_response = { body: [newer_pr, older_pr].to_json }

        expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
          .and_return(multi_response)

        expect(FastlaneCore::UI).to receive(:important)
          .with("Found 2 open PRs from #{branch} into #{base_branch}, using the most recent one")

        result = Fastlane::Helper::GitHubHelper.find_unique_open_pr_number(
          repo_name: repo_name,
          branch: branch,
          base_branch: base_branch,
          api_token: api_token
        )

        expect(result).to eq(42)
      end

      it 'URL-encodes branch names with special characters' do
        special_branch = 'feature/foo&bar#1'
        pr_response = { body: [{ "number" => 7, "title" => "Special" }].to_json }

        expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
          .with(
            server_url: 'https://api.github.com',
            http_method: 'GET',
            path: expected_path_with_base(special_branch, base_branch),
            api_token: api_token
          )
          .and_return(pr_response)

        result = Fastlane::Helper::GitHubHelper.find_unique_open_pr_number(
          repo_name: repo_name,
          branch: special_branch,
          base_branch: base_branch,
          api_token: api_token
        )

        expect(result).to eq(7)
      end
    end

    context 'without base_branch' do
      it 'returns the PR number when exactly one open PR exists' do
        pr_response = { body: [{ "number" => 99, "title" => "Release PR" }].to_json }

        expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
          .with(
            server_url: 'https://api.github.com',
            http_method: 'GET',
            path: expected_path_without_base(branch),
            api_token: api_token
          )
          .and_return(pr_response)

        result = Fastlane::Helper::GitHubHelper.find_unique_open_pr_number(
          repo_name: repo_name,
          branch: branch,
          api_token: api_token
        )

        expect(result).to eq(99)
      end

      it 'raises error when no open PR is found' do
        empty_response = { body: [].to_json }

        expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
          .and_return(empty_response)

        expect do
          Fastlane::Helper::GitHubHelper.find_unique_open_pr_number(
            repo_name: repo_name,
            branch: branch,
            api_token: api_token
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /No open PR found from #{Regexp.escape(branch)}/)
      end

      it 'raises error when multiple open PRs exist' do
        pr1 = { "number" => 42, "title" => "PR to main", "base" => { "ref" => "main" } }
        pr2 = { "number" => 10, "title" => "PR to develop", "base" => { "ref" => "develop" } }
        multi_response = { body: [pr1, pr2].to_json }

        expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
          .and_return(multi_response)

        expect do
          Fastlane::Helper::GitHubHelper.find_unique_open_pr_number(
            repo_name: repo_name,
            branch: branch,
            api_token: api_token
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /Found 2 open PRs.*Specify base_branch to disambiguate/)
      end
    end

    it 'propagates network errors' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_raise(StandardError.new("Connection refused"))

      expect do
        Fastlane::Helper::GitHubHelper.find_unique_open_pr_number(
          repo_name: repo_name,
          branch: branch,
          base_branch: base_branch,
          api_token: api_token
        )
      end.to raise_error(StandardError, /Connection refused/)
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

    it 'raises error if node_id is nil' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: 'https://api.github.com',
          http_method: 'GET',
          path: "/repos/#{repo_name}/pulls/#{pr_number}",
          api_token: api_token
        )
        .and_return({ json: { 'node_id' => nil } })

      expect(Fastlane::Helper::GitHubHelper).not_to receive(:github_api_call_with_retry)
        .with(hash_including(path: '/graphql'))

      expect do
        Fastlane::Helper::GitHubHelper.enable_auto_merge(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: api_token
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Could not retrieve node_id for PR ##{pr_number}/)
    end

    it 'raises error if GraphQL response contains errors' do
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

      expect do
        Fastlane::Helper::GitHubHelper.enable_auto_merge(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: api_token
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Failed to enable auto-merge for PR ##{pr_number}/)
    end

    it 'retries on unstable status error and succeeds' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'GET', path: "/repos/#{repo_name}/pulls/#{pr_number}"))
        .and_return({ json: { 'node_id' => node_id } })

      unstable_response = { json: { 'errors' => [{ 'message' => 'Pull request is in unstable status' }] } }
      success_response = { json: {} }

      call_count = 0
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'POST', path: '/graphql')) do
          call_count += 1
          call_count <= 2 ? unstable_response : success_response
        end

      allow_any_instance_of(Object).to receive(:sleep)

      Fastlane::Helper::GitHubHelper.enable_auto_merge(
        repo_name: repo_name,
        pr_number: pr_number,
        api_token: api_token,
        initial_wait: 1
      )

      expect(call_count).to eq(3)
    end

    it 'raises error after exhausting retries on unstable status' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'GET', path: "/repos/#{repo_name}/pulls/#{pr_number}"))
        .and_return({ json: { 'node_id' => node_id } })

      unstable_response = { json: { 'errors' => [{ 'message' => 'Pull request is in unstable status' }] } }
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'POST', path: '/graphql'))
        .and_return(unstable_response)

      allow_any_instance_of(Object).to receive(:sleep)

      expect do
        Fastlane::Helper::GitHubHelper.enable_auto_merge(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: api_token,
          max_retries: 2,
          initial_wait: 1
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Failed to enable auto-merge for PR ##{pr_number}/)
    end

    it 'does not retry on non-unstable GraphQL errors' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'GET', path: "/repos/#{repo_name}/pulls/#{pr_number}"))
        .and_return({ json: { 'node_id' => node_id } })

      error_response = { json: { 'errors' => [{ 'message' => 'Pull request Auto merge is not allowed for this repository' }] } }
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'POST', path: '/graphql'))
        .once
        .and_return(error_response)

      expect_any_instance_of(Object).not_to receive(:sleep)

      expect do
        Fastlane::Helper::GitHubHelper.enable_auto_merge(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: api_token,
          max_retries: 3,
          initial_wait: 1
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Failed to enable auto-merge for PR ##{pr_number}/)
    end

    it 'uses exponential backoff for wait times' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'GET', path: "/repos/#{repo_name}/pulls/#{pr_number}"))
        .and_return({ json: { 'node_id' => node_id } })

      unstable_response = { json: { 'errors' => [{ 'message' => 'Pull request is in unstable status' }] } }
      call_count = 0
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'POST', path: '/graphql')) do
          call_count += 1
          call_count <= 3 ? unstable_response : { json: {} }
        end

      sleep_times = []
      allow(Fastlane::Helper::GitHubHelper).to receive(:sleep) { |seconds| sleep_times << seconds }

      Fastlane::Helper::GitHubHelper.enable_auto_merge(
        repo_name: repo_name,
        pr_number: pr_number,
        api_token: api_token,
        initial_wait: 10
      )

      expect(sleep_times).to eq([10, 20, 40])
    end
  end

  describe '.enqueue_pr' do
    let(:repo_name) { 'RevenueCat/mock-repo-name' }
    let(:pr_number) { 42 }
    let(:api_token) { 'mock-github-token' }
    let(:node_id) { 'PR_kwDOFake123' }

    it 'enqueues PR into merge queue' do
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
          body: { query: "mutation { enqueuePullRequest(input: {pullRequestId: \"#{node_id}\"}) { mergeQueueEntry { id } } }" },
          api_token: api_token
        )
        .and_return({ json: {} })

      Fastlane::Helper::GitHubHelper.enqueue_pr(
        repo_name: repo_name,
        pr_number: pr_number,
        api_token: api_token
      )
    end

    it 'raises error if node_id is nil' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(
          server_url: 'https://api.github.com',
          http_method: 'GET',
          path: "/repos/#{repo_name}/pulls/#{pr_number}",
          api_token: api_token
        )
        .and_return({ json: { 'node_id' => nil } })

      expect(Fastlane::Helper::GitHubHelper).not_to receive(:github_api_call_with_retry)
        .with(hash_including(path: '/graphql'))

      expect do
        Fastlane::Helper::GitHubHelper.enqueue_pr(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: api_token
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Could not retrieve node_id for PR ##{pr_number}/)
    end

    it 'raises error if GraphQL response contains errors' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'GET', path: "/repos/#{repo_name}/pulls/#{pr_number}"))
        .and_return({ json: { 'node_id' => node_id } })

      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(http_method: 'POST', path: '/graphql'))
        .and_return({ json: { 'errors' => [{ 'message' => 'Merge queue is not enabled for this branch' }] } })

      expect do
        Fastlane::Helper::GitHubHelper.enqueue_pr(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: api_token
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Failed to enqueue PR ##{pr_number}/)
    end

    it 'propagates network errors' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_raise(StandardError.new("Connection refused"))

      expect do
        Fastlane::Helper::GitHubHelper.enqueue_pr(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: api_token
        )
      end.to raise_error(StandardError, /Connection refused/)
    end
  end

  describe '.merge_pr' do
    let(:repo_name) { 'RevenueCat/mock-repo-name' }
    let(:pr_number) { 42 }
    let(:api_token) { 'mock-github-token' }
    let(:captured_handlers) { {} }

    before do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry) do |**kwargs|
        captured_handlers.merge!(kwargs[:error_handlers] || {})
        { status: 200, body: '{"merged": true}' }
      end
    end

    def call_merge_pr(**overrides)
      Fastlane::Helper::GitHubHelper.merge_pr(
        repo_name: repo_name,
        pr_number: pr_number,
        api_token: api_token,
        **overrides
      )
    end

    it 'merges the PR with squash by default' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(
                http_method: 'PUT',
                path: "/repos/#{repo_name}/pulls/#{pr_number}/merge",
                body: { merge_method: 'squash' }
              ))

      call_merge_pr
    end

    it 'downcases the merge method for the REST API' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(body: { merge_method: 'rebase' }))

      call_merge_pr(merge_method: 'REBASE')
    end

    it 'error handler for 405 raises with conflict message' do
      call_merge_pr

      expect { captured_handlers[405].call(body: 'conflict details') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /not mergeable.*conflict details/)
    end

    it 'error handler for 409 raises with checks-not-passed message' do
      call_merge_pr

      expect { captured_handlers[409].call(body: 'checks pending') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /could not be merged.*checks pending/)
    end

    it 'error handler for unexpected status raises with status and body' do
      call_merge_pr

      expect { captured_handlers['*'].call(status: 500, body: 'Internal Server Error') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /500.*Internal Server Error/)
    end

    it 'propagates network errors' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_raise(StandardError.new("Connection refused"))

      expect { call_merge_pr }.to raise_error(StandardError, /Connection refused/)
    end
  end

  describe '.update_pr_branch' do
    let(:repo_name) { 'RevenueCat/mock-repo-name' }
    let(:pr_number) { 42 }
    let(:api_token) { 'mock-github-token' }
    let(:captured_handlers) { {} }

    before do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry) do |**kwargs|
        captured_handlers.merge!(kwargs[:error_handlers] || {})
        { status: 202, body: '{"message": "Updating pull request branch."}' }
      end
    end

    def call_update_pr_branch
      Fastlane::Helper::GitHubHelper.update_pr_branch(
        repo_name: repo_name,
        pr_number: pr_number,
        api_token: api_token
      )
    end

    it 'calls the update-branch endpoint with PUT' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .with(hash_including(
                http_method: 'PUT',
                path: "/repos/#{repo_name}/pulls/#{pr_number}/update-branch",
                body: {}
              ))

      call_update_pr_branch
    end

    it 'error handler for 422 raises with conflict message' do
      call_update_pr_branch

      expect { captured_handlers[422].call(body: 'validation failed') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /Cannot update.*conflicts or unexpected HEAD SHA/)
    end

    it 'error handler for unexpected status raises with status and body' do
      call_update_pr_branch

      expect { captured_handlers['*'].call(status: 500, body: 'Internal Server Error') }
        .to raise_error(FastlaneCore::Interface::FastlaneError, /500.*Internal Server Error/)
    end

    it 'propagates network errors' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_raise(StandardError.new("Connection refused"))

      expect { call_update_pr_branch }.to raise_error(StandardError, /Connection refused/)
    end
  end
end
