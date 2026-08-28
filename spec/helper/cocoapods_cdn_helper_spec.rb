describe Fastlane::Helper::CocoapodsCdnHelper do
  # MD5('PurchasesHybridCommon') starts with 9ad, which is how the CDN shards its index.
  let(:versions_url) { 'https://cdn.cocoapods.org/all_pods_versions_9_a_d.txt' }
  let(:pod_name) { 'PurchasesHybridCommon' }

  # Versions in the index are sorted lexicographically, not semantically, so the
  # 18.x block sits between 1.9.x and 2.x rather than at the end of the line.
  let(:index_body) do
    [
      "PurchasesHybridCommon/1.9.0/18.32.1/18.33.0/2.0.0/9.9.0\n",
      "PurchasesHybridCommonUI/18.32.1/18.33.0\n",
      "SomeOtherPod/1.0.0\n"
    ].join
  end

  describe '#versions_url' do
    it 'shards the url by the first three hex chars of the md5 of the pod name' do
      expect(described_class.versions_url(pod_name)).to eq(versions_url)
    end
  end

  describe '#published_versions' do
    it 'returns every version listed for the pod' do
      stub_request(:get, versions_url).to_return(status: 200, body: index_body)

      expect(described_class.published_versions(pod_name)).to eq(['1.9.0', '18.32.1', '18.33.0', '2.0.0', '9.9.0'])
    end

    it 'does not confuse a pod with another whose name it prefixes' do
      stub_request(:get, versions_url).to_return(status: 200, body: index_body)

      expect(described_class.published_versions(pod_name)).not_to include('18.33.1')
    end

    it 'returns an empty list when the pod is not in the index' do
      stub_request(:get, versions_url).to_return(status: 200, body: "SomeOtherPod/1.0.0\n")

      expect(described_class.published_versions(pod_name)).to eq([])
    end

    it 'warns and returns an empty list when the index cannot be read' do
      stub_request(:get, versions_url).to_return(status: 500, body: 'boom')

      expect(FastlaneCore::UI).to receive(:important).with(/Couldn't read the CocoaPods CDN index for #{pod_name}/)
      expect(described_class.published_versions(pod_name)).to eq([])
    end
  end

  describe '#pinned_pods_in_podspecs' do
    let(:podspec_path) { File.join(Dir.tmpdir, 'RNPurchases.podspec') }

    after do
      FileUtils.rm_f(podspec_path)
    end

    it 'extracts the pinned versions of matching dependencies' do
      File.write(podspec_path, <<~PODSPEC)
        Pod::Spec.new do |spec|
          spec.dependency   "React-Core"
          spec.dependency   "PurchasesHybridCommon", '18.33.1'
          spec.dependency   "PurchasesHybridCommonUI", '18.33.1'
          spec.dependency   "SomethingElse", '1.0.0'
        end
      PODSPEC

      expect(described_class.pinned_pods_in_podspecs([podspec_path], 'PurchasesHybridCommon\w*')).to eq(
        'PurchasesHybridCommon' => '18.33.1',
        'PurchasesHybridCommonUI' => '18.33.1'
      )
    end

    it 'ignores dependencies without a pinned version' do
      File.write(podspec_path, "spec.dependency \"PurchasesHybridCommon\"\n")

      expect(described_class.pinned_pods_in_podspecs([podspec_path], 'PurchasesHybridCommon\w*')).to eq({})
    end

    it 'fails when a podspec is missing' do
      expect(FastlaneCore::UI).to receive(:user_error!).with('Podspec not found: /does/not/exist.podspec')
                                                       .and_raise(StandardError.new('user_error'))

      expect do
        described_class.pinned_pods_in_podspecs(['/does/not/exist.podspec'], 'PurchasesHybridCommon\w*')
      end.to raise_error(StandardError)
    end
  end

  describe '#wait_for_pod' do
    let(:deadline) { Time.now + 600 }

    before do
      allow(described_class).to receive(:sleep)
    end

    it 'returns true immediately when the version is already published' do
      allow(described_class).to receive(:published_versions).with(pod_name).and_return(['18.33.1'])

      expect(FastlaneCore::UI).to receive(:success).with("#{pod_name} 18.33.1 is available on the CocoaPods CDN")
      expect(described_class).not_to receive(:sleep)
      expect(described_class.wait_for_pod(pod_name, '18.33.1', deadline, 60)).to be(true)
    end

    it 'polls until the version shows up' do
      allow(described_class).to receive(:published_versions).with(pod_name).and_return([], [], ['18.33.1'])

      expect(described_class).to receive(:sleep).with(60).twice
      expect(described_class.wait_for_pod(pod_name, '18.33.1', deadline, 60)).to be(true)
    end

    it 'returns false once the deadline has passed' do
      allow(described_class).to receive(:published_versions).with(pod_name).and_return([])

      expect(described_class.wait_for_pod(pod_name, '18.33.1', Time.now - 1, 60)).to be(false)
    end

    it 'never sleeps past the deadline' do
      allow(described_class).to receive(:published_versions).with(pod_name).and_return([], ['18.33.1'])

      # 10s left but a 60s poll interval: sleep the remainder, not the interval.
      expect(described_class).to receive(:sleep).once { |seconds| expect(seconds).to be <= 10 }
      expect(described_class.wait_for_pod(pod_name, '18.33.1', Time.now + 10, 60)).to be(true)
    end
  end

  describe '#wait_for_pods' do
    before do
      allow(described_class).to receive(:sleep)
    end

    it 'waits for every pod' do
      expect(described_class).to receive(:wait_for_pod).with('PurchasesHybridCommon', '18.33.1', anything, 60).and_return(true)
      expect(described_class).to receive(:wait_for_pod).with('PurchasesHybridCommonUI', '18.33.1', anything, 60).and_return(true)

      described_class.wait_for_pods(
        { 'PurchasesHybridCommon' => '18.33.1', 'PurchasesHybridCommonUI' => '18.33.1' }, 600, 60, false
      )
    end

    it 'shares one deadline across every pod so the total wait stays bounded' do
      deadlines = []
      allow(described_class).to receive(:wait_for_pod) do |_pod_name, _version, deadline, _poll|
        deadlines << deadline
        true
      end

      described_class.wait_for_pods(
        { 'PurchasesHybridCommon' => '18.33.1', 'PurchasesHybridCommonUI' => '18.33.1' }, 600, 60, false
      )

      expect(deadlines.uniq.size).to eq(1)
    end

    it 'fails when a pod never shows up' do
      allow(described_class).to receive(:wait_for_pod).and_return(false)

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with("PurchasesHybridCommon 18.33.1 still isn't on the CocoaPods CDN after 10m. Giving up.")
        .and_raise(StandardError.new('user_error'))

      expect do
        described_class.wait_for_pods({ 'PurchasesHybridCommon' => '18.33.1' }, 600, 60, false)
      end.to raise_error(StandardError)
    end

    it 'only warns when soft_fail is set' do
      allow(described_class).to receive(:wait_for_pod).and_return(false)

      expect(FastlaneCore::UI).to receive(:important)
        .with("PurchasesHybridCommon 18.33.1 still isn't on the CocoaPods CDN after 10m. Continuing anyway.")
      expect(FastlaneCore::UI).not_to receive(:user_error!)

      described_class.wait_for_pods({ 'PurchasesHybridCommon' => '18.33.1' }, 600, 60, true)
    end
  end
end
