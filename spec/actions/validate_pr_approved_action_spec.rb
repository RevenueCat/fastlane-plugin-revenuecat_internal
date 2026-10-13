describe Fastlane::Actions::ValidatePrApprovedAction do
  let(:github_token) { 'mock-github-token' }
  let(:pr_url) { 'https://github.com/RevenueCat/purchases-ios/pull/42' }

  def approval_status(overrides)
    {
      approved: false,
      repo: 'RevenueCat/purchases-ios',
      approver: nil,
      permission: nil,
      reviews: [],
      approvers_without_write_access: [],
      approvers_with_unknown_access: [],
      changes_requested_by: [],
      dismissed_reviews_by: []
    }.merge(overrides)
  end

  def run_with_status(status)
    expect(Fastlane::Helper::GitHubHelper).to receive(:pr_approval_status)
      .with(pr_url, github_token)
      .and_return(status)

    Fastlane::Actions::ValidatePrApprovedAction.run(
      github_token: github_token,
      pr_url: pr_url
    )
  end

  describe '#run' do
    it 'succeeds when PR is approved by a user with write permission' do
      expect(Fastlane::UI).to receive(:success)
        .with("PR has been approved by an organization member with write permissions")

      run_with_status(approval_status(approved: true, approver: 'dev1', permission: 'write'))
    end

    it 'says no approvals were found when the PR has no reviews' do
      expect do
        run_with_status(approval_status({}))
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /No approvals found on the release PR/)
    end

    it 'reports that no reviews were found when the PR has none' do
      expect(Fastlane::UI).to receive(:important).with("No reviews found on this PR")

      expect do
        run_with_status(approval_status({}))
      end.to raise_error(FastlaneCore::Interface::FastlaneError)
    end

    it 'lists the reviews found on the PR' do
      reviews = [
        { username: 'reader1', state: 'APPROVED', permission: 'read' },
        { username: 'dev1', state: 'CHANGES_REQUESTED', permission: nil },
        { username: 'dev2', state: 'DISMISSED', permission: nil }
      ]

      expect(Fastlane::UI).to receive(:message).with("Reviews found on this PR:")
      expect(Fastlane::UI).to receive(:message).with("  - reader1 approved it with 'read' permission")
      expect(Fastlane::UI).to receive(:message).with("  - dev1 requested changes")
      expect(Fastlane::UI).to receive(:message).with("  - dev2's review was dismissed")

      expect do
        run_with_status(approval_status(reviews: reviews, approvers_without_write_access: ['reader1'], changes_requested_by: ['dev1'], dismissed_reviews_by: ['dev2']))
      end.to raise_error(FastlaneCore::Interface::FastlaneError)
    end

    it 'lists approvals whose permission level GitHub did not report' do
      reviews = [{ username: 'dev1', state: 'APPROVED', permission: 'unknown' }]

      expect(Fastlane::UI).to receive(:message).with("Reviews found on this PR:")
      expect(Fastlane::UI).to receive(:message).with("  - dev1 approved it, but GitHub didn't report their permission level")

      expect do
        run_with_status(approval_status(reviews: reviews, approvers_with_unknown_access: ['dev1']))
      end.to raise_error(FastlaneCore::Interface::FastlaneError)
    end

    it 'names the approvers that lack write access' do
      expect do
        run_with_status(approval_status(approvers_without_write_access: ['reader1']))
      end.to raise_error(
        FastlaneCore::Interface::FastlaneError,
        %r{approved by reader1, but that account doesn't have write access to RevenueCat/purchases-ios}
      )
    end

    it 'lists every approver that lacks write access' do
      expect do
        run_with_status(approval_status(approvers_without_write_access: %w[reader1 reader2]))
      end.to raise_error(
        FastlaneCore::Interface::FastlaneError,
        /approved by reader1 and reader2, but none of those accounts have write access/
      )
    end

    it 'reports requested changes' do
      expect do
        run_with_status(approval_status(changes_requested_by: ['dev1']))
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /dev1 requested changes on the release PR/)
    end

    it 'reports dismissed reviews' do
      expect do
        run_with_status(approval_status(dismissed_reviews_by: ['dev1']))
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /review on the release PR by dev1 was dismissed/)
    end

    it 'does not blame the approver when GitHub did not report their permission level' do
      expect do
        run_with_status(approval_status(approvers_with_unknown_access: ['dev1'], approvers_without_write_access: []))
      end.to raise_error(
        FastlaneCore::Interface::FastlaneError,
        /approved by dev1, but GitHub didn't report their permission level/
      )
    end

    it 'links the PR and points at reviews as the only source of approvals' do
      expect do
        run_with_status(approval_status({}))
      end.to raise_error(FastlaneCore::Interface::FastlaneError) { |error|
        expect(error.message).to include(pr_url)
        expect(error.message).to include("Only approving reviews on the GitHub PR count for this check")
      }
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.available_options.size).to eq(2)
    end

    it 'has github_token option with correct configuration' do
      option = Fastlane::Actions::ValidatePrApprovedAction.available_options.find { |o| o.key == :github_token }
      expect(option.env_name).to eq("GITHUB_TOKEN")
      expect(option.optional).to be false
    end

    it 'has pr_url option backed by CIRCLE_PULL_REQUEST env var' do
      option = Fastlane::Actions::ValidatePrApprovedAction.available_options.find { |o| o.key == :pr_url }
      expect(option.env_name).to eq("CIRCLE_PULL_REQUEST")
      expect(option.optional).to be false
    end
  end

  describe 'action metadata' do
    it 'has correct description' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.description)
        .to eq("Validates that the current PR is approved by an organization member with write permissions")
    end

    it 'has nil return value' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.return_value).to be_nil
    end

    it 'has correct authors' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.authors).to eq(["RevenueCat"])
    end

    it 'supports all platforms' do
      expect(Fastlane::Actions::ValidatePrApprovedAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::ValidatePrApprovedAction.is_supported?(:android)).to be true
    end
  end
end
