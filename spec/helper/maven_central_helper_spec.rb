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

  describe '#wait_for_artifacts' do
    before do
      allow(Fastlane::Helper::PollingHelper).to receive(:sleep)
    end

    it 'waits for every artifact on Maven Central' do
      expect(Fastlane::Helper::PollingHelper).to receive(:wait_for_all)
        .with({ "#{group_id}:purchases-hybrid-common:20.4.0" => anything, "#{group_id}:purchases-hybrid-common-ui:20.4.0" => anything },
              'Maven Central', 600, 60, true)

      described_class.wait_for_artifacts(group_id, ['purchases-hybrid-common', 'purchases-hybrid-common-ui'], '20.4.0', 600, 60, true)
    end

    it 'succeeds once the pom resolves' do
      stub_request(:head, pom_url).to_return({ status: 404 }, { status: 200 })

      expect(FastlaneCore::UI).to receive(:success).with("#{group_id}:#{artifact_id}:20.4.0 is available on Maven Central")
      described_class.wait_for_artifacts(group_id, [artifact_id], '20.4.0', 600, 60, false)
    end

    it 'fails when an artifact never shows up' do
      stub_request(:head, pom_url).to_return(status: 404)

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with("#{group_id}:#{artifact_id}:20.4.0 still isn't on Maven Central after 0m. Giving up.")
        .and_raise(StandardError.new('user_error'))

      expect do
        described_class.wait_for_artifacts(group_id, [artifact_id], '20.4.0', 0, 60, false)
      end.to raise_error(StandardError)
    end
  end
end
