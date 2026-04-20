describe Fastlane::Helper::UpdateHybridsVersionsFileHelper do
  describe '.get_android_version_for_hybrid_common_version' do
    let(:get_contents_android_build_gradle_response) do
      { json: JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_files/get_contents_phc_android.json")) }
    end

    it 'obtains correct android version from github' do
      expect(Fastlane::Actions::GithubApiAction).to receive(:run).with(
        server_url: "https://api.github.com",
        http_method: 'GET',
        path: "/repos/revenuecat/purchases-hybrid-common/contents/android/gradle/libs.versions.toml?ref=8.10.0-beta.8",
        body: {},
        api_token: 'mock-github-token'
      ).and_return(get_contents_android_build_gradle_response).once
      version = Fastlane::Helper::UpdateHybridsVersionsFileHelper.get_android_version_for_hybrid_common_version('8.10.0-beta.8', 'mock-github-token')
      expect(version).to eq('7.3.1')
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
        body: {},
        api_token: 'mock-github-token'
      ).and_return(get_contents_ios_phc_podspec_3_3_0_response).once
      version = Fastlane::Helper::UpdateHybridsVersionsFileHelper.get_ios_version_for_hybrid_common_version('3.3.0', 'mock-github-token')
      expect(version).to eq('4.9.0')
    end
  end

  describe '.get_js_version_for_hybrid_common_version' do
    let(:get_contents_js_hybrid_mappings_response) do
      { json: JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_files/get_contents_phc_js_hybrid_mappings.json")) }
    end

    def build_contents_response(body_hash)
      { json: { 'content' => Base64.encode64(body_hash.to_json) } }
    end

    it 'obtains correct purchases-js version from github' do
      expect(Fastlane::Actions::GithubApiAction).to receive(:run).with(
        server_url: "https://api.github.com",
        http_method: 'GET',
        path: "/repos/revenuecat/purchases-hybrid-common/contents/purchases-js-hybrid-mappings/package.json?ref=18.0.0",
        body: {},
        api_token: 'mock-github-token'
      ).and_return(get_contents_js_hybrid_mappings_response).once
      version = Fastlane::Helper::UpdateHybridsVersionsFileHelper.get_js_version_for_hybrid_common_version('18.0.0', 'mock-github-token')
      expect(version).to eq('1.34.0')
    end

    it 'raises a user error when the purchases-js dependency is missing' do
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .and_return(build_contents_response({ 'name' => '@revenuecat/purchases-js-hybrid-mappings', 'dependencies' => {} }))
      expect do
        Fastlane::Helper::UpdateHybridsVersionsFileHelper.get_js_version_for_hybrid_common_version('18.0.0', 'mock-github-token')
      end.to raise_exception(FastlaneCore::Interface::FastlaneError, /Could not find purchases-js version/)
    end

    it 'raises a user error when the purchases-js dependency version is empty' do
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .and_return(build_contents_response({ 'dependencies' => { '@revenuecat/purchases-js' => '' } }))
      expect do
        Fastlane::Helper::UpdateHybridsVersionsFileHelper.get_js_version_for_hybrid_common_version('18.0.0', 'mock-github-token')
      end.to raise_exception(FastlaneCore::Interface::FastlaneError, /Could not find purchases-js version/)
    end

    it 'raises when the package.json has no dependencies key at all' do
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .and_return(build_contents_response({ 'name' => '@revenuecat/purchases-js-hybrid-mappings' }))
      expect do
        Fastlane::Helper::UpdateHybridsVersionsFileHelper.get_js_version_for_hybrid_common_version('18.0.0', 'mock-github-token')
      end.to raise_exception(FastlaneCore::Interface::FastlaneError, /Could not find purchases-js version/)
    end
  end
end
