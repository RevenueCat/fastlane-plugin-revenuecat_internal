describe Fastlane::Actions::PingHeartbeatMonitorAction do
  describe '#run' do
    let(:url) { 'https://example.com/heartbeat' }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(Fastlane::Actions).to receive(:sh)
    end

    context 'when not running in CI environment' do
      it 'skips heartbeat ping and returns early' do
        allow(ENV).to receive(:[]).with("CI").and_return("false")
        allow(ENV).to receive(:[]).with("CIRCLE_PULL_REQUEST").and_return(nil)

        expect(Fastlane::Actions).not_to receive(:sh)

        Fastlane::Actions::PingHeartbeatMonitorAction.run(url: url)
      end
    end

    context 'when running in pull request context' do
      it 'skips heartbeat ping and returns early' do
        allow(ENV).to receive(:[]).with("CI").and_return("true")
        allow(ENV).to receive(:[]).with("CIRCLE_PULL_REQUEST").and_return("https://github.com/owner/repo/pull/123")

        expect(Fastlane::Actions).not_to receive(:sh)

        Fastlane::Actions::PingHeartbeatMonitorAction.run(url: url)
      end
    end

    context 'when running in CI and not in pull request' do
      before do
        allow(ENV).to receive(:[]).with("CI").and_return("true")
        allow(ENV).to receive(:[]).with("CIRCLE_PULL_REQUEST").and_return(nil)
      end

      context 'when url parameter is provided' do
        it 'pings the heartbeat monitor with the provided url' do
          expect(Fastlane::Actions).to receive(:sh).with("curl -m 5 --retry 3 #{url}")

          Fastlane::Actions::PingHeartbeatMonitorAction.run(url: url)
        end
      end

      context 'when url parameter is not provided' do
        context 'and HEARTBEAT_MONITOR_URL environment variable is set' do
          it 'pings the heartbeat monitor with the environment variable url' do
            allow(ENV).to receive(:fetch).with("HEARTBEAT_MONITOR_URL", nil).and_return(url)

            expect(Fastlane::Actions).to receive(:sh).with("curl -m 5 --retry 3 #{url}")

            Fastlane::Actions::PingHeartbeatMonitorAction.run({})
          end
        end

        context 'and HEARTBEAT_MONITOR_URL environment variable is not set' do
          it 'fails with a user error' do
            allow(ENV).to receive(:fetch).with("HEARTBEAT_MONITOR_URL", nil).and_return(nil)

            expect(Fastlane::UI).to receive(:user_error!).with("No url parameter nor HEARTBEAT_MONITOR_URL environment variable provided")

            Fastlane::Actions::PingHeartbeatMonitorAction.run({})
          end
        end
      end
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::PingHeartbeatMonitorAction.available_options.size).to eq(1)
    end

    it 'has url option that is optional' do
      url_option = Fastlane::Actions::PingHeartbeatMonitorAction.available_options.first
      expect(url_option.key).to eq(:url)
      expect(url_option.optional).to eq(true)
    end
  end
end
