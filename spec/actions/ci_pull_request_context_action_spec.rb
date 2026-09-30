describe Fastlane::Actions::CiPullRequestContextAction do
  let(:action) { described_class }

  it 'returns pull-request head metadata from CircleCI values' do
    expect(
      action.run(
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

  it 'prefers the pull-request URL over a merge-queue branch' do
    expect(
      action.run(
        pull_request_url: 'https://github.com/RevenueCat/purchases-ios/pull/123',
        head_sha: 'head-sha',
        head_ref: 'gh-readonly-queue/main/pr-456-abcdef1234'
      )
    ).to eq(
      pr_number: '123',
      head_sha: 'head-sha',
      head_ref: 'gh-readonly-queue/main/pr-456-abcdef1234'
    )
  end

  it 'returns merge-queue metadata and supports base branches containing slashes' do
    expect(
      action.run(
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

    expect(action.run({})).to include(
      pr_number: '456',
      head_sha: 'head-sha',
      head_ref: 'gh-readonly-queue/main/pr-456-abcdef1234',
      base_ref: 'main'
    )
  end

  it 'returns an empty context outside a pull request' do
    expect(action.run(head_ref: 'main')).to eq({})
  end

  describe '.available_options' do
    it 'reads pull-request, commit, and branch values from CircleCI' do
      options = action.available_options.to_h { |option| [option.key, option.env_name] }

      expect(options).to include(
        pull_request_url: 'CIRCLE_PULL_REQUEST',
        head_sha: 'CIRCLE_SHA1',
        head_ref: 'CIRCLE_BRANCH'
      )
    end
  end
end
