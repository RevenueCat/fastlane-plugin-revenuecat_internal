describe Fastlane::Actions::WaitForArtifactsInMavenCentralAction do
  describe '#run' do
    let(:group_id) { 'com.revenuecat.purchases' }
    let(:artifact_ids) { ['purchases-hybrid-common', 'purchases-hybrid-common-ui'] }

    it 'passes soft_fail through' do
      expect(Fastlane::Helper::MavenCentralHelper).to receive(:wait_for_artifacts)
        .with(group_id, artifact_ids, '20.4.0', 600, 30, true)

      Fastlane::FastFile.new.parse("lane :test do
        wait_for_artifacts_in_maven_central(group_id: 'com.revenuecat.purchases',
                                            artifact_ids: ['purchases-hybrid-common', 'purchases-hybrid-common-ui'],
                                            version: '20.4.0',
                                            timeout: 600,
                                            poll_interval: 30,
                                            soft_fail: true)
      end").runner.execute(:test)
    end

    it 'defaults to a one hour wait polled every minute' do
      expect(Fastlane::Helper::MavenCentralHelper).to receive(:wait_for_artifacts)
        .with(group_id, artifact_ids, '20.4.0', 3600, 60, false)

      Fastlane::FastFile.new.parse("lane :test do
        wait_for_artifacts_in_maven_central(group_id: 'com.revenuecat.purchases',
                                            artifact_ids: ['purchases-hybrid-common', 'purchases-hybrid-common-ui'],
                                            version: '20.4.0')
      end").runner.execute(:test)
    end

    it 'fails when no artifacts are given' do
      expect do
        Fastlane::FastFile.new.parse("lane :test do
          wait_for_artifacts_in_maven_central(group_id: 'com.revenuecat.purchases',
                                              artifact_ids: [],
                                              version: '20.4.0')
        end").runner.execute(:test)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /No artifacts provided/)
    end
  end
end
