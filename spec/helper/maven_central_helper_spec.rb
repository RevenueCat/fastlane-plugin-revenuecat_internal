describe Fastlane::Helper::MavenCentralHelper do
  let(:group_id) { 'com.revenuecat.purchases' }
  let(:artifact_id) { 'purchases-hybrid-common' }
  let(:pom_url) do
    'https://repo1.maven.org/maven2/com/revenuecat/purchases/purchases-hybrid-common/20.4.0/purchases-hybrid-common-20.4.0.pom'
  end

  describe '#pom_url' do
    it 'builds the repo1 path from the group, artifact and version' do
      expect(described_class.pom_url(group_id, artifact_id, '20.4.0')).to eq(pom_url)
    end
  end

  describe '#artifact_available?' do
    it 'is true when the pom exists' do
      stub_request(:head, pom_url).to_return(status: 200)

      expect(described_class.artifact_available?(group_id, artifact_id, '20.4.0')).to be(true)
    end

    it 'is false when the pom is not there yet' do
      stub_request(:head, pom_url).to_return(status: 404)

      expect(FastlaneCore::UI).not_to receive(:important)
      expect(described_class.artifact_available?(group_id, artifact_id, '20.4.0')).to be(false)
    end

    it 'warns and is false when the request fails' do
      stub_request(:head, pom_url).to_return(status: 500)

      expect(FastlaneCore::UI).to receive(:important).with(/Couldn't check #{group_id}:#{artifact_id}:20.4.0 on Maven Central/)
      expect(described_class.artifact_available?(group_id, artifact_id, '20.4.0')).to be(false)
    end
  end

  describe '#wait_for_artifact' do
    let(:deadline) { Time.now + 600 }

    before do
      allow(described_class).to receive(:sleep)
    end

    it 'returns true immediately when the artifact is already available' do
      allow(described_class).to receive(:artifact_available?).and_return(true)

      expect(described_class).not_to receive(:sleep)
      expect(described_class.wait_for_artifact(group_id, artifact_id, '20.4.0', deadline, 60)).to be(true)
    end

    it 'polls until the artifact shows up' do
      allow(described_class).to receive(:artifact_available?).and_return(false, false, true)

      expect(described_class).to receive(:sleep).with(60).twice
      expect(described_class.wait_for_artifact(group_id, artifact_id, '20.4.0', deadline, 60)).to be(true)
    end

    it 'returns false once the deadline has passed' do
      allow(described_class).to receive(:artifact_available?).and_return(false)

      expect(described_class.wait_for_artifact(group_id, artifact_id, '20.4.0', Time.now - 1, 60)).to be(false)
    end

    it 'never sleeps past the deadline' do
      allow(described_class).to receive(:artifact_available?).and_return(false, true)

      expect(described_class).to receive(:sleep).once { |seconds| expect(seconds).to be <= 10 }
      expect(described_class.wait_for_artifact(group_id, artifact_id, '20.4.0', Time.now + 10, 60)).to be(true)
    end
  end

  describe '#wait_for_artifacts' do
    it 'waits for every artifact against one shared deadline' do
      deadlines = []
      allow(described_class).to receive(:wait_for_artifact) do |_group_id, _artifact_id, _version, deadline, _poll|
        deadlines << deadline
        true
      end

      described_class.wait_for_artifacts(group_id, ['purchases-hybrid-common', 'purchases-hybrid-common-ui'], '20.4.0', 600, 60, false)

      expect(deadlines.size).to eq(2)
      expect(deadlines.uniq.size).to eq(1)
    end

    it 'fails when an artifact never shows up' do
      allow(described_class).to receive(:wait_for_artifact).and_return(false)

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with("#{group_id}:#{artifact_id}:20.4.0 still isn't on Maven Central after 10m. Giving up.")
        .and_raise(StandardError.new('user_error'))

      expect do
        described_class.wait_for_artifacts(group_id, [artifact_id], '20.4.0', 600, 60, false)
      end.to raise_error(StandardError)
    end

    it 'only warns when soft_fail is set' do
      allow(described_class).to receive(:wait_for_artifact).and_return(false)

      expect(FastlaneCore::UI).to receive(:important)
        .with("#{group_id}:#{artifact_id}:20.4.0 still isn't on Maven Central after 10m. Continuing anyway.")
      expect(FastlaneCore::UI).not_to receive(:user_error!)

      described_class.wait_for_artifacts(group_id, [artifact_id], '20.4.0', 600, 60, true)
    end
  end
end
