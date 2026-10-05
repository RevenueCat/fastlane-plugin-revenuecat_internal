describe Fastlane::Actions::CiPullRequestContextAction do
  let(:action) { described_class }

  it 'delegates to the CI helper' do
    params = {
      pull_request_url: 'https://github.com/RevenueCat/purchases-ios/pull/123',
      head_sha: 'head-sha',
      head_ref: 'feature/sentry'
    }
    context = {
      pr_number: '123',
      head_sha: 'head-sha',
      head_ref: 'feature/sentry'
    }

    expect(Fastlane::Helper::CiHelper).to receive(:pull_request_context)
      .with(**params)
      .and_return(context)

    expect(action.run(params)).to eq(context)
  end

  it 'supports direct Ruby calls using CircleCI environment variables' do
    allow(ENV).to receive(:fetch).with('CIRCLE_PULL_REQUEST', '').and_return('https://github.com/RevenueCat/purchases-ios/pull/123')
    allow(ENV).to receive(:fetch).with('CIRCLE_SHA1', '').and_return('head-sha')
    allow(ENV).to receive(:fetch).with('CIRCLE_BRANCH', '').and_return('feature/sentry')

    expect(action.run({})).to eq(
      pr_number: '123',
      head_sha: 'head-sha',
      head_ref: 'feature/sentry'
    )
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
