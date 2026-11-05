describe Fastlane::Helper::PollingHelper do
  let(:description) { 'PurchasesHybridCommon 18.33.1' }
  let(:where) { 'the CocoaPods CDN' }

  before do
    allow(described_class).to receive(:sleep)
  end

  describe '#wait_until' do
    let(:deadline) { Time.now + 600 }

    it 'returns true immediately when the check already passes' do
      expect(FastlaneCore::UI).to receive(:success).with("#{description} is available on #{where}")
      expect(described_class).not_to receive(:sleep)
      expect(described_class.wait_until(description, where, deadline, 60, -> { true })).to be(true)
    end

    it 'polls until the check passes' do
      results = [false, false, true]

      expect(described_class).to receive(:sleep).with(60).twice
      expect(described_class.wait_until(description, where, deadline, 60, -> { results.shift })).to be(true)
    end

    it 'logs on every poll' do
      results = [false, true]

      expect(FastlaneCore::UI).to receive(:message).with(/Waiting for #{description} on #{where} \(\d+m remaining\)\.\.\./)
      described_class.wait_until(description, where, deadline, 60, -> { results.shift })
    end

    it 'returns false once the deadline has passed' do
      expect(described_class.wait_until(description, where, Time.now - 1, 60, -> { false })).to be(false)
    end

    it 'never sleeps past the deadline' do
      results = [false, true]

      # 10s left but a 60s poll interval: sleep the remainder, not the interval.
      expect(described_class).to receive(:sleep).once { |seconds| expect(seconds).to be <= 10 }
      expect(described_class.wait_until(description, where, Time.now + 10, 60, -> { results.shift })).to be(true)
    end
  end

  describe '#wait_for_all' do
    let(:checks) { { 'PurchasesHybridCommon 18.33.1' => -> { true }, 'PurchasesHybridCommonUI 18.33.1' => -> { true } } }

    it 'waits for every check' do
      expect(described_class).to receive(:wait_until).with('PurchasesHybridCommon 18.33.1', where, anything, 60, anything).and_return(true)
      expect(described_class).to receive(:wait_until).with('PurchasesHybridCommonUI 18.33.1', where, anything, 60, anything).and_return(true)

      described_class.wait_for_all(checks, where, 600, 60, false)
    end

    it 'shares one deadline across every check so the total wait stays bounded' do
      deadlines = []
      allow(described_class).to receive(:wait_until) do |_description, _where, deadline, _poll, _available|
        deadlines << deadline
        true
      end

      described_class.wait_for_all(checks, where, 600, 60, false)

      expect(deadlines.size).to eq(2)
      expect(deadlines.uniq.size).to eq(1)
    end

    it 'fails when a check never passes' do
      allow(described_class).to receive(:wait_until).and_return(false)

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with("PurchasesHybridCommon 18.33.1 still isn't on the CocoaPods CDN after 10m. Giving up.")
        .and_raise(StandardError.new('user_error'))

      expect do
        described_class.wait_for_all({ description => -> { false } }, where, 600, 60, false)
      end.to raise_error(StandardError)
    end

    it 'only warns when soft_fail is set' do
      allow(described_class).to receive(:wait_until).and_return(false)

      expect(FastlaneCore::UI).to receive(:important)
        .with("PurchasesHybridCommon 18.33.1 still isn't on the CocoaPods CDN after 10m. Continuing anyway.")
      expect(FastlaneCore::UI).not_to receive(:user_error!)

      described_class.wait_for_all({ description => -> { false } }, where, 600, 60, true)
    end
  end
end
