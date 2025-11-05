describe Fastlane::Actions::SlackBackendIntegrationTestResultsAction do
  describe '#run' do
    let(:environment) { 'production' }
    let(:version) { '8.0.0' }
    let(:platform) { 'iOS' }
    let(:slack_url_feed) { 'https://hooks.slack.com/services/FEED' }
    let(:slack_url_binary_solo) { 'https://hooks.slack.com/services/BINARY' }
    let(:circle_build_url) { 'https://app.circleci.com/pipelines/github/RevenueCat/repo/123/workflows/456' }
    let(:circle_job) { 'backend-integration-tests' }
    let(:repo_name) { 'purchases-ios' }
    let(:git_branch) { 'main' }
    let(:action_instance) { Fastlane::Actions::SlackBackendIntegrationTestResultsAction }
    let(:mock_runner) { double('Runner') }
    let(:mock_other_action) { double('OtherAction') }

    before(:each) do
      ENV['CI'] = 'true'
      ENV['CIRCLE_BUILD_URL'] = circle_build_url
      ENV['CIRCLE_JOB'] = circle_job
      ENV['CIRCLE_PROJECT_REPONAME'] = repo_name
      ENV['SLACK_URL_BACKEND_INTEGRATION_TESTS'] = slack_url_feed
      ENV['SLACK_URL_BINARY_SOLO'] = slack_url_binary_solo

      allow(Fastlane::Actions).to receive(:sh)
        .with("git rev-parse --abbrev-ref HEAD")
        .and_return(git_branch)      
      allow(mock_other_action).to receive(:slack)
      allow(mock_other_action).to receive(:runner).and_return(mock_runner)
      allow(mock_runner).to receive(:trigger_action_by_name)
      allow(action_instance).to receive(:runner).and_return(mock_runner)
      allow(action_instance).to receive(:other_action).and_return(mock_other_action)
    end

    after(:each) do
      ENV.delete('CI')
      ENV.delete('CIRCLE_BUILD_URL')
      ENV.delete('CIRCLE_JOB')
      ENV.delete('CIRCLE_PROJECT_REPONAME')
      ENV.delete('SLACK_URL_BACKEND_INTEGRATION_TESTS')
      ENV.delete('SLACK_URL_BINARY_SOLO')
    end

    describe 'when tests succeed' do
      it 'sends success message to feed channel only' do
        expected_message = "#{platform} backend integration tests finished successfully."

        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            message: expected_message,
            slack_url: slack_url_feed,
            success: true
          )
        )

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end

      it 'includes correct attachment fields' do
        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            success: true,
            default_payloads: [],
            attachment_properties: hash_including(
              fields: array_including(
                hash_including(title: 'SDK', value: repo_name, short: true),
                hash_including(title: 'SDK version', value: '8', short: true),
                hash_including(title: 'Git branch', value: git_branch, short: true),
                hash_including(title: 'Environment', value: environment, short: true),
                hash_including(title: 'Test suite', value: circle_job, short: false)
              ),
              actions: array_including(
                hash_including(
                  type: 'button',
                  text: 'View CircleCI logs',
                  url: circle_build_url
                )
              )
            )
          )
        )

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end
    end

    describe 'when tests fail' do
      it 'sends failure messages to both feed and binary-solo channels' do
        expected_binary_solo_message = "<!subteam^S0939BTV0SY|oncall-sdk> <!subteam^S061NM11SNN|oncall-infra> <!subteam^S0621D5SHG9|oncall-product> #{platform} backend integration tests failed."
        expected_feed_message = "#{platform} backend integration tests failed. On-call is pinged in <#CL407G2QL|binary-solo>."

        # Expect call to binary-solo (with on-call ping)
        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            message: expected_binary_solo_message,
            slack_url: slack_url_binary_solo,
            success: false
          )
        ).ordered

        # Expect call to feed channel
        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            message: expected_feed_message,
            slack_url: slack_url_feed,
            success: false
          )
        ).ordered

        action_instance.run(
          environment: environment,
          success: false,
          version: version,
          platform: platform
        )
      end

      it 'defaults to false when success parameter is not provided' do
        expect(mock_other_action).to receive(:slack).twice

        action_instance.run(
          environment: environment,
          version: version,
          platform: platform
        )
      end
    end

    describe 'version handling' do
      it 'uses provided version parameter' do
        expect(mock_other_action).to receive(:slack).once

        action_instance.run(
          environment: environment,
          success: true,
          version: '9.0.0',
          platform: platform
        )
      end

      it 'reads version from .version file when not provided' do
        allow(File).to receive(:readlines)
          .with(File.expand_path('.version', Dir.pwd))
          .and_return(["10.0.0\n"])

        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            attachment_properties: hash_including(
              fields: array_including(
                hash_including(title: 'SDK version', value: '10')
              )
            )
          )
        )

        action_instance.run(
          environment: environment,
          success: true,
          platform: platform
        )
      end

      it 'handles version with whitespace in .version file' do
        allow(File).to receive(:readlines)
          .with(File.expand_path('.version', Dir.pwd))
          .and_return(["  11.0.0  \n"])

        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            attachment_properties: hash_including(
              fields: array_including(
                hash_including(title: 'SDK version', value: '11')
              )
            )
          )
        )

        action_instance.run(
          environment: environment,
          success: true,
          platform: platform
        )
      end

      it 'fails when version cannot be determined' do
        allow(File).to receive(:readlines)
          .with(File.expand_path('.version', Dir.pwd))
          .and_raise(StandardError)

        expect(FastlaneCore::UI).to receive(:user_error!)
          .with('Missing version parameter')
          .and_call_original

        expect do
          action_instance.run(
            environment: environment,
            success: true,
            platform: platform
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end
    end

    describe 'platform detection' do
      it 'infers iOS from purchases-ios repo name' do
        ENV['CIRCLE_PROJECT_REPONAME'] = 'purchases-ios'

        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            message: 'iOS backend integration tests finished successfully.'
          )
        )

        action_instance.run(
          environment: environment,
          success: true,
          version: version
        )
      end

      it 'infers Android from purchases-android repo name' do
        ENV['CIRCLE_PROJECT_REPONAME'] = 'purchases-android'

        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            message: 'Android backend integration tests finished successfully.'
          )
        )

        action_instance.run(
          environment: environment,
          success: true,
          version: version
        )
      end

      it 'uses explicit platform parameter over inferred value' do
        ENV['CIRCLE_PROJECT_REPONAME'] = 'purchases-android'

        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            message: 'iOS backend integration tests finished successfully.'
          )
        )

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: 'iOS'
        )
      end

      it 'succeeds when platform is explicitly provided despite unknown repo name' do
        ENV['CIRCLE_PROJECT_REPONAME'] = 'unknown-repo'

        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            message: 'Android backend integration tests finished successfully.'
          )
        )

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: 'Android'
        )
      end

      it 'fails when platform cannot be inferred' do
        ENV['CIRCLE_PROJECT_REPONAME'] = 'unknown-repo'

        expect(FastlaneCore::UI).to receive(:user_error!)
          .with('Missing platform parameter')
          .and_call_original

        expect do
          action_instance.run(
            environment: environment,
            success: true,
            version: version
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end
    end

    describe 'when not in CI environment' do
      it 'skips slack notification and shows message' do
        ENV['CI'] = 'false'

        expect(Fastlane::UI).to receive(:message)
          .with('Not running in CI environment, skipping slack notification.')

        # Should not call slack
        expect(mock_other_action).not_to receive(:slack)

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end

      it 'skips when CI env var is not set' do
        ENV.delete('CI')

        expect(Fastlane::UI).to receive(:message)
          .with('Not running in CI environment, skipping slack notification.')

        expect(mock_other_action).not_to receive(:slack)

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end
    end

    describe 'missing environment variables' do
      it 'fails when SLACK_URL_BACKEND_INTEGRATION_TESTS is missing' do
        ENV.delete('SLACK_URL_BACKEND_INTEGRATION_TESTS')

        expect(FastlaneCore::UI).to receive(:user_error!)
          .with('Missing required SLACK_URL_BACKEND_INTEGRATION_TESTS environment variable. Make sure to provide the slack-secrets CircleCI context.')
          .and_call_original

        expect do
          action_instance.run(
            environment: environment,
            success: true,
            version: version,
            platform: platform
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end

      it 'fails when SLACK_URL_BINARY_SOLO is missing' do
        ENV.delete('SLACK_URL_BINARY_SOLO')

        expect(FastlaneCore::UI).to receive(:user_error!)
          .with('Missing required SLACK_URL_BINARY_SOLO environment variable. Make sure to provide the slack-secrets CircleCI context.')
          .and_call_original

        expect do
          action_instance.run(
            environment: environment,
            success: true,
            version: version,
            platform: platform
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end
    end

    describe 'major version extraction' do
      it 'extracts major version from semantic version' do
        expect(mock_other_action).to receive(:slack).once.with(
          hash_including(
            attachment_properties: hash_including(
              fields: array_including(
                hash_including(title: 'SDK version', value: '12')
              )
            )
          )
        )

        action_instance.run(
          environment: environment,
          success: true,
          version: '12.5.3',
          platform: platform
        )
      end
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::SlackBackendIntegrationTestResultsAction.available_options.size).to eq(4)
    end
  end
end

