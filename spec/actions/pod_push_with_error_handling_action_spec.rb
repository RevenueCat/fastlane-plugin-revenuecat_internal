require 'fastlane'
require 'fastlane_core/ui/ui'

describe Fastlane::Actions::PodPushWithErrorHandlingAction do
  describe '#run' do
    let(:podspec_path) { 'RevenueCat.podspec' }

    before do
      allow(FastlaneCore::UI).to receive(:message)
      allow(FastlaneCore::UI).to receive(:error)
      allow(FastlaneCore::UI).to receive(:success)
      allow(FastlaneCore::UI).to receive(:important)
      allow(FastlaneCore::UI).to receive(:user_error!)

      # Default: the pod is not on trunk. Individual tests override as needed.
      allow(described_class).to receive(:pod_published?).and_return(false)
    end

    it 'returns true when pod push succeeds and does not check trunk' do
      allow(Fastlane::Actions::PodPushAction).to receive(:run).and_return('Successfully pushed')

      result = described_class.run(path: podspec_path)

      expect(result).to eq(true)
      expect(Fastlane::Actions::PodPushAction).to have_received(:run).once
      expect(described_class).not_to have_received(:pod_published?)
    end

    it 'treats the push as successful when it errors but the pod is on trunk' do
      allow(Fastlane::Actions::PodPushAction).to receive(:run).and_raise(StandardError.new('Exit status of command was 1 instead of 0.'))
      allow(described_class).to receive(:pod_published?).with(podspec_path).and_return(true)

      result = described_class.run(path: podspec_path)

      expect(result).to eq(true)
      expect(FastlaneCore::UI).to have_received(:important).with("✅ Pod is already published to CocoaPods trunk. Treating the push as successful.")
    end

    it 'raises a PodPushUnknownError when the push errors and the pod is not on trunk' do
      allow(Fastlane::Actions::PodPushAction).to receive(:run).and_raise(StandardError.new('Some unexpected failure'))

      expect(FastlaneCore::UI).to receive(:error).with("❌ Pod push failed with an unknown error and won't retry. You can rerun this job using SSH. Error: Some unexpected failure")

      expect do
        described_class.run(path: podspec_path)
      end.to raise_error(Fastlane::Actions::PodPushUnknownError, "❌ Pod push failed: Some unexpected failure")
    end

    it 'retries up to 3 times on GitHub API timeout' do
      error_message = '[!] Calling the GitHub commit API timed out.'
      call_count = 0

      allow(Fastlane::Actions::PodPushAction).to receive(:run) do
        call_count += 1
        raise StandardError, error_message if call_count <= 3

        'Successfully pushed' # ✅ Succeed on the 4th attempt
      end

      # Mock sleep to prevent actual delays during testing
      allow_any_instance_of(Object).to receive(:sleep)

      expect(FastlaneCore::UI).to receive(:important).with(/Retrying in \d+ seconds/).exactly(3).times
      expect(FastlaneCore::UI).to receive(:message).with(/Attempt \d/).exactly(4).times # 3 failures + 1 success

      result = described_class.run(
        path: podspec_path,
        synchronous: true,
        verbose: false,
        allow_warnings: false
      )

      expect(result).to eq(true) # ✅ Ensure success on the 4th attempt
    end

    it 'retries up to 3 times when spec sources do not contain a satisfying dependency' do
      error_message = "None of your spec sources contain a spec satisfying the dependency: `PurchasesHybridCommon (= 18.2.0)`."
      call_count = 0

      allow(Fastlane::Actions::PodPushAction).to receive(:run) do
        call_count += 1
        raise StandardError, error_message if call_count <= 3

        'Successfully pushed'
      end

      allow_any_instance_of(Object).to receive(:sleep)

      expect(FastlaneCore::UI).to receive(:important).with(/Retrying in \d+ seconds/).exactly(3).times
      expect(FastlaneCore::UI).to receive(:message).with(/Attempt \d/).exactly(4).times

      result = described_class.run(
        path: podspec_path,
        synchronous: true,
        verbose: false,
        allow_warnings: false
      )

      expect(result).to eq(true)
    end

    it 'retries up to 3 times on internal server error' do
      error_message = '[!] An internal server error occurred. Please check for any known status issues at https://twitter.com/CocoaPods and try again later.'
      call_count = 0

      allow(Fastlane::Actions::PodPushAction).to receive(:run) do
        call_count += 1
        raise StandardError, error_message if call_count <= 3

        'Successfully pushed' # ✅ Succeed on the 4th attempt
      end

      # Mock sleep to prevent actual delays during testing
      allow_any_instance_of(Object).to receive(:sleep)

      expect(FastlaneCore::UI).to receive(:important).with(/Retrying in \d+ seconds/).exactly(3).times
      expect(FastlaneCore::UI).to receive(:message).with(/Attempt \d/).exactly(4).times # 3 failures + 1 success

      result = described_class.run(
        path: podspec_path,
        synchronous: true,
        verbose: false,
        allow_warnings: false
      )

      expect(result).to eq(true) # ✅ Ensure success on the 4th attempt
    end

    it 'returns false after exhausting retries on a persistent retryable error' do
      allow(Fastlane::Actions::PodPushAction).to receive(:run).and_raise(StandardError.new('[!] Calling the GitHub commit API timed out.'))
      allow_any_instance_of(Object).to receive(:sleep)

      result = described_class.run(path: podspec_path)

      expect(result).to eq(false)
      expect(FastlaneCore::UI).to have_received(:error).with("❌ Pod push failed after 3 retries due to persistent server issues.")
    end
  end

  describe '#pod_published?' do
    let(:podspec_path) { 'RevenueCat.podspec' }
    let(:pod_name) { 'RevenueCat' }
    let(:pod_version) { '5.81.0' }
    let(:trunk_url) { "https://trunk.cocoapods.org/api/v1/pods/#{pod_name}" }

    before do
      allow(FastlaneCore::UI).to receive(:important)
    end

    # Stubs `pod ipc spec <path>` to return a spec JSON for the given name/version.
    def stub_pod_ipc_spec(name:, version:, success: true)
      status = instance_double(Process::Status, success?: success)
      body = success ? { name: name, version: version }.to_json : ''
      allow(Open3).to receive(:capture3).with('pod', 'ipc', 'spec', podspec_path).and_return([body, '', status])
    end

    it 'returns true when the version is listed on trunk' do
      stub_pod_ipc_spec(name: pod_name, version: pod_version)
      stub_request(:get, trunk_url).to_return(status: 200, body: { versions: [{ name: '5.80.0' }, { name: pod_version }] }.to_json)

      expect(described_class.pod_published?(podspec_path)).to eq(true)
    end

    it 'returns false when the version is not listed on trunk' do
      stub_pod_ipc_spec(name: pod_name, version: pod_version)
      stub_request(:get, trunk_url).to_return(status: 200, body: { versions: [{ name: '5.80.0' }] }.to_json)

      expect(described_class.pod_published?(podspec_path)).to eq(false)
    end

    it 'returns false when the trunk request is not successful' do
      stub_pod_ipc_spec(name: pod_name, version: pod_version)
      stub_request(:get, trunk_url).to_return(status: 404, body: '')

      expect(described_class.pod_published?(podspec_path)).to eq(false)
    end

    it 'returns false when the trunk request raises' do
      stub_pod_ipc_spec(name: pod_name, version: pod_version)
      stub_request(:get, trunk_url).to_raise(SocketError.new('no connection'))

      expect(described_class.pod_published?(podspec_path)).to eq(false)
    end

    it 'returns false when reading the podspec fails' do
      stub_pod_ipc_spec(name: pod_name, version: pod_version, success: false)

      expect(described_class.pod_published?(podspec_path)).to eq(false)
    end
  end

  describe '#available_options' do
    it 'requires a path parameter' do
      options = Fastlane::Actions::PodPushWithErrorHandlingAction.available_options
      path_option = options.find { |opt| opt.key == :path }

      expect(path_option).not_to be_nil
      expect(path_option.optional).to eq(false)
      expect(path_option.data_type).to eq(String)
    end
  end
end
