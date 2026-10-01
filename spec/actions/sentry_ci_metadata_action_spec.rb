describe Fastlane::Actions::SentryCiMetadataAction do
  let(:action) { described_class }
  let(:params) do
    {
      org_slug: 'revenuecat',
      project_slug: 'purchases-android'
    }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('CIRCLE_PULL_REQUEST', nil).and_return(nil)
    allow(ENV).to receive(:fetch).with('CIRCLE_SHA1', nil).and_return('head-sha')
    allow(ENV).to receive(:fetch).with('CIRCLE_BRANCH', nil).and_return('feature/sentry')
  end

  it 'returns the common Sentry metadata outside a pull request' do
    expect(Fastlane::Actions::CiPullRequestContextAction).to receive(:run)
      .with(
        pull_request_url: nil,
        head_sha: 'head-sha',
        head_ref: 'feature/sentry'
      )
      .and_return({})

    expect(action.run(params)).to eq(
      org_slug: 'revenuecat',
      project_slug: 'purchases-android',
      force_git_metadata: true
    )
  end

  it 'merges ordinary pull-request context without interpreting it' do
    pull_request_context = {
      pr_number: '123',
      head_sha: 'head-sha',
      head_ref: 'feature/sentry'
    }
    allow(Fastlane::Actions::CiPullRequestContextAction).to receive(:run)
      .and_return(pull_request_context)

    expect(action.run(params)).to include(pull_request_context)
  end

  it 'merges merge-queue base metadata without interpreting it' do
    pull_request_context = {
      pr_number: '456',
      head_sha: 'head-sha',
      head_ref: 'gh-readonly-queue/release/9.x/pr-456-abcdef1234',
      base_sha: 'abcdef1234',
      base_ref: 'release/9.x'
    }
    allow(Fastlane::Actions::CiPullRequestContextAction).to receive(:run)
      .and_return(pull_request_context)

    expect(action.run(params)).to include(pull_request_context)
  end

  describe '.available_options' do
    it 'requires only the Sentry organization and project' do
      options = action.available_options.to_h { |option| [option.key, option] }

      expect(options.keys).to contain_exactly(:org_slug, :project_slug)
      expect(options.values).to all(satisfy { |option| !option.optional })
    end
  end
end
