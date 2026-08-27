describe Fastlane::Actions::WaitForPodsInCocoapodsCdnAction do
  describe '#run' do
    let(:pods) { { 'PurchasesHybridCommon' => '18.33.1' } }

    it 'waits for the pods given explicitly' do
      expect(Fastlane::Helper::CocoapodsCdnHelper).to receive(:wait_for_pods).with(pods, 600, 30, false)

      Fastlane::FastFile.new.parse("lane :test do
        wait_for_pods_in_cocoapods_cdn(pods: { 'PurchasesHybridCommon' => '18.33.1' },
                                       timeout: 600,
                                       poll_interval: 30)
      end").runner.execute(:test)
    end

    it 'passes soft_fail through' do
      expect(Fastlane::Helper::CocoapodsCdnHelper).to receive(:wait_for_pods).with(pods, 600, 30, true)

      Fastlane::FastFile.new.parse("lane :test do
        wait_for_pods_in_cocoapods_cdn(pods: { 'PurchasesHybridCommon' => '18.33.1' },
                                       timeout: 600,
                                       poll_interval: 30,
                                       soft_fail: true)
      end").runner.execute(:test)
    end

    it 'defaults to a three hour wait polled every minute' do
      expect(Fastlane::Helper::CocoapodsCdnHelper).to receive(:wait_for_pods).with(pods, 10_800, 60, false)

      Fastlane::FastFile.new.parse("lane :test do
        wait_for_pods_in_cocoapods_cdn(pods: { 'PurchasesHybridCommon' => '18.33.1' })
      end").runner.execute(:test)
    end

    it 'reads the pinned versions from podspecs when :pods is not given' do
      expect(Fastlane::Helper::CocoapodsCdnHelper).to receive(:pinned_pods_in_podspecs)
        .with(['RNPurchases.podspec'], 'PurchasesHybridCommon\w*')
        .and_return(pods)
      expect(Fastlane::Helper::CocoapodsCdnHelper).to receive(:wait_for_pods).with(pods, 10_800, 60, false)

      Fastlane::FastFile.new.parse("lane :test do
        wait_for_pods_in_cocoapods_cdn(podspec_paths: ['RNPurchases.podspec'])
      end").runner.execute(:test)
    end

    it 'honours a custom pod name pattern' do
      expect(Fastlane::Helper::CocoapodsCdnHelper).to receive(:pinned_pods_in_podspecs)
        .with(['RNPurchases.podspec'], 'RevenueCat.*')
        .and_return(pods)
      allow(Fastlane::Helper::CocoapodsCdnHelper).to receive(:wait_for_pods)

      Fastlane::FastFile.new.parse("lane :test do
        wait_for_pods_in_cocoapods_cdn(podspec_paths: ['RNPurchases.podspec'],
                                       pod_name_pattern: 'RevenueCat.*')
      end").runner.execute(:test)
    end

    it 'fails when neither pods nor podspec_paths are given' do
      expect do
        Fastlane::FastFile.new.parse("lane :test do
          wait_for_pods_in_cocoapods_cdn
        end").runner.execute(:test)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, 'Either :pods or :podspec_paths must be provided')
    end

    it 'fails when the podspecs contain no matching dependency' do
      allow(Fastlane::Helper::CocoapodsCdnHelper).to receive(:pinned_pods_in_podspecs).and_return({})

      expect do
        Fastlane::FastFile.new.parse("lane :test do
          wait_for_pods_in_cocoapods_cdn(podspec_paths: ['RNPurchases.podspec'])
        end").runner.execute(:test)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Found no pods to wait for/)
    end
  end
end
