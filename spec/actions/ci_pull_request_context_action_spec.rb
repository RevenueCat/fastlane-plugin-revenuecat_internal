describe Fastlane::Actions::CiPullRequestContextAction do
  let(:action) { described_class }

  it 'returns the pull-request number from its URL' do
    expect(action.run(pull_request_url: 'https://github.com/RevenueCat/purchases-ios/pull/123')).to eq(
      pr_number: '123'
    )
  end

  it 'prefers the pull-request URL over a merge-queue branch' do
    expect(
      action.run(
        pull_request_url: 'https://github.com/RevenueCat/purchases-ios/pull/123',
        branch: 'gh-readonly-queue/main/pr-456-abcdef1234'
      )
    ).to eq(pr_number: '123')
  end

  it 'returns merge-queue metadata and supports base branches containing slashes' do
    expect(action.run(branch: 'gh-readonly-queue/release/9.x/pr-456-abcdef1234')).to eq(
      pr_number: '456',
      base_ref: 'release/9.x',
      base_sha: 'abcdef1234'
    )
  end

  it 'falls back to the current Git branch' do
    allow(Fastlane::Actions).to receive(:git_branch)
      .and_return('gh-readonly-queue/main/pr-456-abcdef1234')

    expect(action.run({})).to include(pr_number: '456', base_ref: 'main')
  end

  it 'returns an empty context outside a pull request' do
    expect(action.run(branch: 'main')).to eq({})
  end

  describe '.available_options' do
    it 'reads pull-request and branch values from CircleCI' do
      options = action.available_options.to_h { |option| [option.key, option.env_name] }

      expect(options).to include(
        pull_request_url: 'CIRCLE_PULL_REQUEST',
        branch: 'CIRCLE_BRANCH'
      )
    end
  end
end
