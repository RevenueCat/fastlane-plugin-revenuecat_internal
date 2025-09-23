describe Fastlane::Actions::CheckGithubAuthenticationAction do
  describe '#run' do
    let(:github_token) { 'mock-github-token' }
    let(:auth_status) { { authenticated: true, rate_limit: { remaining: 100 } } }

    it 'calls GitHubHelper.check_authentication_and_rate_limits with the provided token' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:check_authentication_and_rate_limits)
        .with(github_token)
        .and_return(auth_status)

      result = Fastlane::Actions::CheckGithubAuthenticationAction.run(
        github_token: github_token
      )

      expect(result).to eq(auth_status)
    end

    it 'shows helpful messages when authentication fails' do
      failed_auth_status = { authenticated: false, rate_limit: { remaining: 100 } }

      expect(Fastlane::Helper::GitHubHelper).to receive(:check_authentication_and_rate_limits)
        .with(github_token)
        .and_return(failed_auth_status)

      expect(Fastlane::UI).to receive(:message).with("- Set environment variable")
      expect(Fastlane::UI).to receive(:message).with("- Ensure your token has the required permissions")
      expect(Fastlane::UI).to receive(:message).with("- Check that the token hasn't expired")
      expect(Fastlane::UI).to receive(:message).with("- Token ending in: ...oken")

      result = Fastlane::Actions::CheckGithubAuthenticationAction.run(
        github_token: github_token
      )

      expect(result).to eq(failed_auth_status)
    end

    it 'shows helpful messages without token info for short tokens' do
      short_token = "abc"
      failed_auth_status = { authenticated: false, rate_limit: { remaining: 100 } }

      expect(Fastlane::Helper::GitHubHelper).to receive(:check_authentication_and_rate_limits)
        .with(short_token)
        .and_return(failed_auth_status)

      expect(Fastlane::UI).to receive(:message).with("- Set environment variable")
      expect(Fastlane::UI).to receive(:message).with("- Ensure your token has the required permissions")
      expect(Fastlane::UI).to receive(:message).with("- Check that the token hasn't expired")
      expect(Fastlane::UI).not_to receive(:message).with(/Token ending in/)

      result = Fastlane::Actions::CheckGithubAuthenticationAction.run(
        github_token: short_token
      )

      expect(result).to eq(failed_auth_status)
    end

    it 'works with nil token' do
      expect(Fastlane::Helper::GitHubHelper).to receive(:check_authentication_and_rate_limits)
        .with(nil)
        .and_return({ authenticated: false, rate_limit: nil })

      result = Fastlane::Actions::CheckGithubAuthenticationAction.run(
        github_token: nil
      )

      expect(result[:authenticated]).to be false
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CheckGithubAuthenticationAction.available_options.size).to eq(1)
    end

    it 'has github_token option with correct configuration' do
      option = Fastlane::Actions::CheckGithubAuthenticationAction.available_options.first
      expect(option.key).to eq(:github_token)
      expect(option.env_name).to eq("RC_INTERNAL_GITHUB_TOKEN")
      expect(option.optional).to be true
    end
  end

  describe 'action metadata' do
    it 'has correct description' do
      expect(Fastlane::Actions::CheckGithubAuthenticationAction.description)
        .to eq("Checks GitHub authentication status and current rate limits")
    end

    it 'has correct return value description' do
      expect(Fastlane::Actions::CheckGithubAuthenticationAction.return_value)
        .to eq("Hash containing authentication status and rate limit information")
    end

    it 'has correct authors' do
      expect(Fastlane::Actions::CheckGithubAuthenticationAction.authors).to eq(["RevenueCat"])
    end

    it 'supports all platforms' do
      expect(Fastlane::Actions::CheckGithubAuthenticationAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::CheckGithubAuthenticationAction.is_supported?(:android)).to be true
    end
  end
end
