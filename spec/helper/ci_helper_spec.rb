describe Fastlane::Helper::CiHelper do
  let(:helper) { described_class }

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('CIRCLE_PULL_REQUEST', '').and_return('')
    allow(ENV).to receive(:fetch).with('CIRCLE_SHA1', '').and_return('')
    allow(ENV).to receive(:fetch).with('CIRCLE_BRANCH', '').and_return('')
  end

  it 'returns pull-request head metadata from explicit values' do
    expect(
      helper.pull_request_context(
        pull_request_url: 'https://github.com/RevenueCat/purchases-ios/pull/123',
        head_sha: 'head-sha',
        head_ref: 'feature/sentry'
      )
    ).to eq(
      pr_number: '123',
      head_sha: 'head-sha',
      head_ref: 'feature/sentry'
    )
  end

  it 'reads CircleCI environment variables by default' do
    allow(ENV).to receive(:fetch).with('CIRCLE_PULL_REQUEST', '').and_return('https://github.com/RevenueCat/purchases-ios/pull/123')
    allow(ENV).to receive(:fetch).with('CIRCLE_SHA1', '').and_return('head-sha')
    allow(ENV).to receive(:fetch).with('CIRCLE_BRANCH', '').and_return('feature/sentry')

    expect(helper.pull_request_context).to eq(
      pr_number: '123',
      head_sha: 'head-sha',
      head_ref: 'feature/sentry'
    )
  end

  it 'prefers merge-queue metadata when a pull-request URL is also present' do
    expect(
      helper.pull_request_context(
        pull_request_url: 'https://github.com/RevenueCat/purchases-ios/pull/123',
        head_sha: 'head-sha',
        head_ref: 'gh-readonly-queue/main/pr-456-abcdef1234'
      )
    ).to eq(
      pr_number: '456',
      head_sha: 'head-sha',
      head_ref: 'gh-readonly-queue/main/pr-456-abcdef1234',
      base_ref: 'main',
      base_sha: 'abcdef1234'
    )
  end

  it 'returns merge-queue metadata and supports base branches containing slashes' do
    expect(
      helper.pull_request_context(
        head_sha: 'head-sha',
        head_ref: 'gh-readonly-queue/release/9.x/pr-456-abcdef1234'
      )
    ).to eq(
      pr_number: '456',
      head_sha: 'head-sha',
      head_ref: 'gh-readonly-queue/release/9.x/pr-456-abcdef1234',
      base_ref: 'release/9.x',
      base_sha: 'abcdef1234'
    )
  end

  it 'falls back to the current Git commit and branch' do
    allow(Fastlane::Actions).to receive(:last_git_commit_hash)
      .with(false)
      .and_return('head-sha')
    allow(Fastlane::Actions).to receive(:git_branch_name_using_HEAD)
      .and_return('gh-readonly-queue/main/pr-456-abcdef1234')

    expect(helper.pull_request_context).to include(
      pr_number: '456',
      head_sha: 'head-sha',
      head_ref: 'gh-readonly-queue/main/pr-456-abcdef1234',
      base_ref: 'main'
    )
  end

  it 'returns an empty context outside a pull request' do
    expect(helper.pull_request_context(head_ref: 'main')).to eq({})
  end
end
