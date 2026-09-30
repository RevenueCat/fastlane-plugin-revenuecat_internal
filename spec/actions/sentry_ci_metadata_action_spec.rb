describe Fastlane::Actions::SentryCiMetadataAction do
  let(:action) { described_class }
  let(:params) do
    {
      repo_name: 'purchases-android',
      repo_owner: 'RevenueCat',
      org_slug: 'revenuecat',
      project_slug: 'purchases-android',
      github_token: nil
    }
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('CIRCLE_SHA1').and_return('head-sha')
    allow(ENV).to receive(:[]).with('CIRCLE_PULL_REQUEST').and_return(nil)
    allow(ENV).to receive(:[]).with('DANGER_GITHUB_API_TOKEN').and_return(nil)
    allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return(nil)
    allow(Fastlane::Actions).to receive(:git_branch).and_return('feature/sentry')
  end

  it 'returns common Sentry metadata for a branch build' do
    expect(action.run(params)).to eq(
      org_slug: 'revenuecat',
      project_slug: 'purchases-android',
      vcs_provider: 'github',
      head_repo_name: 'RevenueCat/purchases-android',
      base_repo_name: 'RevenueCat/purchases-android',
      force_git_metadata: true,
      head_sha: 'head-sha',
      head_ref: 'feature/sentry'
    )
  end

  it 'falls back to the git SHA outside CircleCI and omits a detached HEAD ref' do
    allow(ENV).to receive(:[]).with('CIRCLE_SHA1').and_return(nil)
    allow(Fastlane::Actions).to receive(:sh).with('git', 'rev-parse', 'HEAD', log: false).and_return("local-sha\n")
    allow(Fastlane::Actions).to receive(:git_branch).and_return('HEAD')

    expect(action.run(params)).to include(head_sha: 'local-sha')
    expect(action.run(params)).not_to have_key(:head_ref)
  end

  it 'adds pull-request and fork repository metadata from CIRCLE_PULL_REQUEST' do
    allow(ENV).to receive(:[]).with('CIRCLE_PULL_REQUEST').and_return('https://github.com/RevenueCat/purchases-android/pull/123')
    params[:github_token] = 'token'
    expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
      .with(
        server_url: 'https://api.github.com',
        api_token: 'token',
        http_method: 'GET',
        path: '/repos/RevenueCat/purchases-android/pulls/123'
      )
      .and_return(
        json: {
          'head' => { 'repo' => { 'full_name' => 'contributor/purchases-android' } },
          'base' => {
            'sha' => 'base-sha',
            'ref' => 'main',
            'repo' => { 'full_name' => 'RevenueCat/purchases-android' }
          }
        }
      )

    expect(action.run(params)).to include(
      pr_number: '123',
      base_sha: 'base-sha',
      base_ref: 'main',
      head_repo_name: 'contributor/purchases-android',
      base_repo_name: 'RevenueCat/purchases-android'
    )
  end

  it 'falls back to DANGER_GITHUB_API_TOKEN for pull-request metadata' do
    allow(ENV).to receive(:[]).with('CIRCLE_PULL_REQUEST').and_return('https://github.com/RevenueCat/purchases-android/pull/123')
    allow(ENV).to receive(:[]).with('DANGER_GITHUB_API_TOKEN').and_return('danger-token')
    expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
      .with(hash_including(api_token: 'danger-token'))
      .and_return(json: { 'base' => { 'sha' => 'base-sha', 'ref' => 'main' } })

    expect(action.run(params)).to include(pr_number: '123')
  end

  it 'falls back to GITHUB_TOKEN when the Danger token is unavailable' do
    allow(ENV).to receive(:[]).with('CIRCLE_PULL_REQUEST').and_return('https://github.com/RevenueCat/purchases-android/pull/123')
    allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return('github-token')
    expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
      .with(hash_including(api_token: 'github-token'))
      .and_return(json: { 'base' => { 'sha' => 'base-sha', 'ref' => 'main' } })

    expect(action.run(params)).to include(pr_number: '123')
  end

  it 'prefers an explicit GitHub token over environment tokens' do
    allow(ENV).to receive(:[]).with('CIRCLE_PULL_REQUEST').and_return('https://github.com/RevenueCat/purchases-android/pull/123')
    allow(ENV).to receive(:[]).with('DANGER_GITHUB_API_TOKEN').and_return('danger-token')
    allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return('github-token')
    params[:github_token] = 'explicit-token'
    expect(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
      .with(hash_including(api_token: 'explicit-token'))
      .and_return(json: { 'base' => { 'sha' => 'base-sha', 'ref' => 'main' } })

    expect(action.run(params)).to include(pr_number: '123')
  end

  it 'uses the base metadata encoded in merge-queue branch names without calling GitHub' do
    allow(Fastlane::Actions).to receive(:git_branch)
      .and_return('gh-readonly-queue/release/9.x/pr-456-abcdef1234')
    expect(Fastlane::Helper::GitHubHelper).not_to receive(:github_api_call_with_retry)

    expect(action.run(params)).to include(
      pr_number: '456',
      base_sha: 'abcdef1234',
      base_ref: 'release/9.x'
    )
  end

  it 'requires a GitHub token for pull-request uploads' do
    allow(ENV).to receive(:[]).with('CIRCLE_PULL_REQUEST').and_return('https://github.com/RevenueCat/purchases-android/pull/123')

    expect { action.run(params) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /GITHUB_TOKEN is required/)
  end

  it 'fails when GitHub does not return a PR base SHA' do
    allow(ENV).to receive(:[]).with('CIRCLE_PULL_REQUEST').and_return('https://github.com/RevenueCat/purchases-android/pull/123')
    params[:github_token] = 'token'
    allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry).and_return(json: {})

    expect { action.run(params) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /Could not determine the base SHA/)
  end

  describe '.available_options' do
    it 'uses RevenueCat as the default repository owner' do
      option = action.available_options.find { |item| item.key == :repo_owner }
      expect(option.default_value).to eq('RevenueCat')
    end

    it 'reads the GitHub token from DANGER_GITHUB_API_TOKEN' do
      option = action.available_options.find { |item| item.key == :github_token }
      expect(option.env_name).to eq('DANGER_GITHUB_API_TOKEN')
    end
  end
end
