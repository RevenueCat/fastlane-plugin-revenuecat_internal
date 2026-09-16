describe Fastlane::Actions::SlackBackendIntegrationTestResultsAction do
  # Mirrors the shape of a CircleCI v1.1 build entry, which is where the job name and status live.
  def build_entry(job:, build_num:, status:)
    { 'build_num' => build_num, 'status' => status, 'workflows' => { 'job_name' => job } }
  end
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

    before(:each) do
      ENV['CI'] = 'true'
      ENV['CIRCLE_BUILD_URL'] = circle_build_url
      ENV['CIRCLE_JOB'] = circle_job
      ENV['CIRCLE_PROJECT_REPONAME'] = repo_name
      ENV['SLACK_URL_BACKEND_INTEGRATION_TESTS'] = slack_url_feed
      ENV['SLACK_URL_BINARY_SOLO'] = slack_url_binary_solo
      ENV['CIRCLE_BUILD_NUM'] = '200'
      ENV['CIRCLE_PROJECT_USERNAME'] = 'RevenueCat'
      # Backup and clear CIRCLE_PULL_REQUEST as it will be set on CI which prevents this action from running.
      @backup_circle_pull_request = ENV.fetch('CIRCLE_PULL_REQUEST', nil)
      ENV.delete('CIRCLE_PULL_REQUEST')

      allow(Fastlane::Actions).to receive(:sh)
        .with("git rev-parse --abbrev-ref HEAD")
        .and_return(git_branch)
      allow(action_instance).to receive(:post_to_slack)
    end

    after(:each) do
      ENV.delete('CI')
      ENV.delete('CIRCLE_BUILD_URL')
      ENV.delete('CIRCLE_JOB')
      ENV.delete('CIRCLE_PROJECT_REPONAME')
      ENV.delete('SLACK_URL_BACKEND_INTEGRATION_TESTS')
      ENV.delete('SLACK_URL_BINARY_SOLO')
      ENV.delete('CIRCLE_BUILD_NUM')
      ENV.delete('CIRCLE_PROJECT_USERNAME')
      ENV['CIRCLE_PULL_REQUEST'] = @backup_circle_pull_request if @backup_circle_pull_request
    end

    # Returns the headline text rendered in the top-level section block, which is where the
    # on-call mention lives so it renders reliably on every Slack client (including mobile).
    def headline_text(payload)
      payload[:blocks].first[:text][:text]
    end

    def attachment(payload)
      payload[:attachments].first
    end

    def field_values(payload)
      attachment(payload)[:blocks].first[:fields].map { |field| field[:text] }
    end

    describe 'when tests succeed' do
      it 'sends success message to feed channel only' do
        expected_message = "#{platform} backend integration tests finished successfully."

        expect(action_instance).not_to receive(:post_to_slack).with(slack_url_binary_solo, anything)
        expect(action_instance).to receive(:post_to_slack).once do |url, payload|
          expect(url).to eq(slack_url_feed)
          expect(payload[:text]).to eq(expected_message)
          expect(headline_text(payload)).to eq(expected_message)
          expect(attachment(payload)[:color]).to eq('#36A64F')
        end

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end

      it 'includes correct details and CircleCI logs button' do
        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(field_values(payload)).to include(
            "*SDK*\n#{repo_name}",
            "*SDK version*\n8",
            "*Git branch*\n#{git_branch}",
            "*Environment*\n#{environment}",
            "*Test suite*\n#{circle_job}"
          )

          actions_block = attachment(payload)[:blocks].find { |block| block[:type] == 'actions' }
          expect(actions_block).not_to be_nil
          button = actions_block[:elements].first
          expect(button[:text][:text]).to eq('View CircleCI logs')
          expect(button[:url]).to eq(circle_build_url)
        end

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end
    end

    describe 'when tests fail' do
      it 'pings on-call in the feed channel by default' do
        expected_feed_message = "<!subteam^S0939BTV0SY|oncall-sdk> #{platform} backend integration tests failed."

        expect(action_instance).not_to receive(:post_to_slack).with(slack_url_binary_solo, anything)
        expect(action_instance).to receive(:post_to_slack).once do |url, payload|
          expect(url).to eq(slack_url_feed)
          expect(payload[:text]).to eq(expected_feed_message)
          expect(headline_text(payload)).to eq(expected_feed_message)
          expect(attachment(payload)[:color]).to eq('#D00000')
        end

        action_instance.run(
          environment: environment,
          success: false,
          version: version,
          platform: platform
        )
      end

      it 'also notifies binary-solo when message_binary_solo_on_failure is explicitly true' do
        expected_message = "<!subteam^S0939BTV0SY|oncall-sdk> #{platform} backend integration tests failed."

        expect(action_instance).to receive(:post_to_slack).once.ordered do |url, payload|
          expect(url).to eq(slack_url_binary_solo)
          expect(headline_text(payload)).to eq(expected_message)
        end
        expect(action_instance).to receive(:post_to_slack).once.ordered do |url, payload|
          expect(url).to eq(slack_url_feed)
          expect(headline_text(payload)).to eq(expected_message)
        end

        action_instance.run(
          environment: environment,
          success: false,
          version: version,
          platform: platform,
          message_binary_solo_on_failure: true
        )
      end

      it 'defaults to failure when success parameter is not provided' do
        expect(action_instance).to receive(:post_to_slack).once do |url, payload|
          expect(url).to eq(slack_url_feed)
          expect(attachment(payload)[:color]).to eq('#D00000')
        end

        action_instance.run(
          environment: environment,
          version: version,
          platform: platform
        )
      end
    end

    describe 'version handling' do
      it 'uses provided version parameter' do
        expect(action_instance).to receive(:post_to_slack).once

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

        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(field_values(payload)).to include("*SDK version*\n10")
        end

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

        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(field_values(payload)).to include("*SDK version*\n11")
        end

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

        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(headline_text(payload)).to eq('iOS backend integration tests finished successfully.')
        end

        action_instance.run(
          environment: environment,
          success: true,
          version: version
        )
      end

      it 'infers Android from purchases-android repo name' do
        ENV['CIRCLE_PROJECT_REPONAME'] = 'purchases-android'

        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(headline_text(payload)).to eq('Android backend integration tests finished successfully.')
        end

        action_instance.run(
          environment: environment,
          success: true,
          version: version
        )
      end

      it 'uses explicit platform parameter over inferred value' do
        ENV['CIRCLE_PROJECT_REPONAME'] = 'purchases-android'

        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(headline_text(payload)).to eq('iOS backend integration tests finished successfully.')
        end

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: 'iOS'
        )
      end

      it 'succeeds when platform is explicitly provided despite unknown repo name' do
        ENV['CIRCLE_PROJECT_REPONAME'] = 'unknown-repo'

        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(headline_text(payload)).to eq('Android backend integration tests finished successfully.')
        end

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

        expect(action_instance).not_to receive(:post_to_slack)

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

        expect(action_instance).not_to receive(:post_to_slack)

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end
    end

    describe 'when running in pull request context' do
      it 'skips slack notification when CIRCLE_PULL_REQUEST is set to a URL' do
        ENV['CIRCLE_PULL_REQUEST'] = 'https://github.com/RevenueCat/repo/pull/123'

        expect(Fastlane::UI).to receive(:message)
          .with('Running in pull request context, skipping slack notification.')

        expect(action_instance).not_to receive(:post_to_slack)

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end

      it 'continues normally when CIRCLE_PULL_REQUEST is not set' do
        ENV.delete('CIRCLE_PULL_REQUEST')

        expect(action_instance).to receive(:post_to_slack).once

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end

      it 'continues normally when CIRCLE_PULL_REQUEST is set to empty string' do
        ENV['CIRCLE_PULL_REQUEST'] = ''

        expect(action_instance).to receive(:post_to_slack).once

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

      it 'fails when SLACK_URL_BINARY_SOLO is missing and binary-solo notifications are enabled' do
        ENV.delete('SLACK_URL_BINARY_SOLO')

        expect(FastlaneCore::UI).to receive(:user_error!)
          .with('Missing required SLACK_URL_BINARY_SOLO environment variable. Make sure to provide the slack-secrets CircleCI context.')
          .and_call_original

        expect do
          action_instance.run(
            environment: environment,
            success: false,
            version: version,
            platform: platform,
            message_binary_solo_on_failure: true
          )
        end.to raise_error(FastlaneCore::Interface::FastlaneError)
      end

      it 'does not require SLACK_URL_BINARY_SOLO when binary-solo notifications are disabled' do
        ENV.delete('SLACK_URL_BINARY_SOLO')

        expect(action_instance).to receive(:post_to_slack).once

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end
    end

    describe 'recovery notifications' do
      def run_with_recovery_notifications(success:)
        action_instance.run(
          environment: environment,
          success: success,
          version: version,
          platform: platform,
          notify_success_only_on_recovery: true
        )
      end

      it 'posts a recovery message when the previous run of the job on the branch failed' do
        allow(action_instance).to receive(:fetch_recent_builds)
          .and_return([build_entry(job: circle_job, build_num: 90, status: 'failed')])

        expect(action_instance).to receive(:post_to_slack).once do |url, payload|
          expect(url).to eq(slack_url_feed)
          expect(payload[:text]).to eq("#{platform} backend integration tests recovered.")
          expect(headline_text(payload)).to eq("#{platform} backend integration tests recovered.")
          expect(attachment(payload)[:color]).to eq('#36A64F')
        end

        run_with_recovery_notifications(success: true)
      end

      it 'posts nothing when the previous run of the job on the branch succeeded' do
        allow(action_instance).to receive(:fetch_recent_builds)
          .and_return([build_entry(job: circle_job, build_num: 90, status: 'success')])

        expect(action_instance).not_to receive(:post_to_slack)

        run_with_recovery_notifications(success: true)
      end

      it 'posts nothing when the branch has no previous run of the job' do
        allow(action_instance).to receive(:fetch_recent_builds)
          .and_return([build_entry(job: 'some-other-job', build_num: 90, status: 'failed')])

        expect(action_instance).not_to receive(:post_to_slack)

        run_with_recovery_notifications(success: true)
      end

      it 'posts the success message when the previous status cannot be determined' do
        allow(action_instance).to receive(:fetch_recent_builds).and_return(nil)

        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(payload[:text]).to eq("#{platform} backend integration tests finished successfully.")
        end

        run_with_recovery_notifications(success: true)
      end

      it 'posts the failure message without looking up the previous status' do
        expect(action_instance).not_to receive(:fetch_recent_builds)
        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(payload[:text]).to eq("<!subteam^S0939BTV0SY|oncall-sdk> #{platform} backend integration tests failed.")
        end

        run_with_recovery_notifications(success: false)
      end

      it 'posts every success when the option is not enabled' do
        expect(action_instance).not_to receive(:fetch_recent_builds)
        expect(action_instance).to receive(:post_to_slack).once

        action_instance.run(
          environment: environment,
          success: true,
          version: version,
          platform: platform
        )
      end
    end

    describe 'major version extraction' do
      it 'extracts major version from semantic version' do
        expect(action_instance).to receive(:post_to_slack).once do |_url, payload|
          expect(field_values(payload)).to include("*SDK version*\n12")
        end

        action_instance.run(
          environment: environment,
          success: true,
          version: '12.5.3',
          platform: platform
        )
      end
    end
  end

  describe '#previous_job_status' do
    let(:action_instance) { Fastlane::Actions::SlackBackendIntegrationTestResultsAction }
    let(:circle_job) { 'integration-tests-all' }
    let(:git_branch) { 'main' }

    def status(build_num: 200)
      action_instance.previous_job_status(job: circle_job, branch: git_branch, build_num: build_num)
    end

    def page_of(entries, size: 100)
      entries + Array.new(size - entries.size) do |index|
        build_entry(job: 'filler-job', build_num: index, status: 'success')
      end
    end

    it 'reports the status of the most recent earlier run of the same job' do
      allow(action_instance).to receive(:fetch_recent_builds).and_return([
                                                                           build_entry(job: circle_job, build_num: 150, status: 'failed'),
                                                                           build_entry(job: circle_job, build_num: 100, status: 'success')
                                                                         ])

      expect(status).to eq(:failed)
    end

    it 'ignores runs of other jobs' do
      allow(action_instance).to receive(:fetch_recent_builds).and_return([
                                                                           build_entry(job: 'some-other-job', build_num: 150, status: 'failed'),
                                                                           build_entry(job: circle_job, build_num: 100, status: 'success')
                                                                         ])

      expect(status).to eq(:success)
    end

    it 'ignores the current build and anything newer' do
      allow(action_instance).to receive(:fetch_recent_builds).and_return([
                                                                           build_entry(job: circle_job, build_num: 250, status: 'failed'),
                                                                           build_entry(job: circle_job, build_num: 200, status: 'failed'),
                                                                           build_entry(job: circle_job, build_num: 150, status: 'success')
                                                                         ])

      expect(status).to eq(:success)
    end

    it 'looks further back when the most recent earlier run was canceled' do
      allow(action_instance).to receive(:fetch_recent_builds).and_return([
                                                                           build_entry(job: circle_job, build_num: 150, status: 'canceled'),
                                                                           build_entry(job: circle_job, build_num: 100, status: 'failed')
                                                                         ])

      expect(status).to eq(:failed)
    end

    it 'treats a timed out run as a failure' do
      allow(action_instance).to receive(:fetch_recent_builds)
        .and_return([build_entry(job: circle_job, build_num: 150, status: 'timedout')])

      expect(status).to eq(:failed)
    end

    it 'reports none when the branch history holds no earlier run of the job' do
      allow(action_instance).to receive(:fetch_recent_builds)
        .and_return([build_entry(job: 'some-other-job', build_num: 150, status: 'failed')])

      expect(status).to eq(:none)
    end

    it 'keeps paging while every page is full' do
      allow(action_instance).to receive(:fetch_recent_builds).with(branch: git_branch, offset: 0)
                                                             .and_return(page_of([]))
      allow(action_instance).to receive(:fetch_recent_builds).with(branch: git_branch, offset: 100)
                                                             .and_return(page_of([build_entry(job: circle_job, build_num: 100, status: 'failed')]))

      expect(status).to eq(:failed)
    end

    it 'reports unknown when the job is not found before the page limit' do
      allow(action_instance).to receive(:fetch_recent_builds).and_return(page_of([]))

      expect(status).to eq(:unknown)
    end

    it 'reports unknown when the builds cannot be fetched' do
      allow(action_instance).to receive(:fetch_recent_builds).and_return(nil)

      expect(status).to eq(:unknown)
    end

    it 'reports unknown without calling CircleCI when the current build number is missing' do
      expect(action_instance).not_to receive(:fetch_recent_builds)

      expect(status(build_num: nil)).to eq(:unknown)
    end
  end

  describe '#recent_builds_url' do
    let(:action_instance) { Fastlane::Actions::SlackBackendIntegrationTestResultsAction }

    before(:each) do
      ENV['CIRCLE_PROJECT_USERNAME'] = 'RevenueCat'
      ENV['CIRCLE_PROJECT_REPONAME'] = 'purchases-ios'
    end

    after(:each) do
      ENV.delete('CIRCLE_PROJECT_USERNAME')
      ENV.delete('CIRCLE_PROJECT_REPONAME')
    end

    it 'escapes the slash in a branch name' do
      url = action_instance.recent_builds_url(branch: 'facu/some-branch', offset: 0)

      expect(url).to start_with('https://circleci.com/api/v1.1/project/github/RevenueCat/purchases-ios/tree/facu%2Fsome-branch?')
    end

    it 'is nil when the project is unknown' do
      ENV.delete('CIRCLE_PROJECT_USERNAME')

      expect(action_instance.recent_builds_url(branch: 'main', offset: 0)).to be_nil
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::SlackBackendIntegrationTestResultsAction.available_options.size).to eq(6)
    end
  end
end
