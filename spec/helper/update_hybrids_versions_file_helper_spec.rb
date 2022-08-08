describe Fastlane::Helper::UpdateHybridsVersionsFileHelper do
  describe '.get_android_version_for_hybrid_common_version' do
    let(:get_contents_android_build_gradle_3_3_0_response) do
      { json: JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_files/get_contents_phc_android.json")) }
    end

    it 'obtains correct android version from github' do
      expect(Fastlane::Actions::GithubApiAction).to receive(:run).with(
        server_url: "https://api.github.com",
        http_method: 'GET',
        path: "/repos/revenuecat/purchases-hybrid-common/contents/android/build.gradle?ref=3.3.0",
        body: {}
      ).and_return(get_contents_android_build_gradle_3_3_0_response).once
      version = Fastlane::Helper::UpdateHybridsVersionsFileHelper.get_android_version_for_hybrid_common_version('3.3.0')
      expect(version).to eq('5.3.0')
    end
  end

  describe '.get_ios_version_for_hybrid_common_version' do
    let(:get_contents_ios_phc_podspec_3_3_0_response) do
      { json: JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_files/get_contents_phc_ios.json")) }
    end

    it 'obtains correct android version from github' do
      expect(Fastlane::Actions::GithubApiAction).to receive(:run).with(
        server_url: "https://api.github.com",
        http_method: 'GET',
        path: "/repos/revenuecat/purchases-hybrid-common/contents/PurchasesHybridCommon.podspec?ref=3.3.0",
        body: {}
      ).and_return(get_contents_ios_phc_podspec_3_3_0_response).once
      version = Fastlane::Helper::UpdateHybridsVersionsFileHelper.get_ios_version_for_hybrid_common_version('3.3.0')
      expect(version).to eq('4.9.0')
    end
  end
end
