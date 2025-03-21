require 'fastlane'
require 'fastlane_core/ui/ui'

describe Fastlane::Actions::PodPushWithErrorHandlingAction do
  describe '#run' do
    let(:podspec_path) { 'RevenueCat.podspec' }

    before do
      allow(FastlaneCore::UI).to receive(:message) # Suppress UI messages
      allow(FastlaneCore::UI).to receive(:error)
      allow(FastlaneCore::UI).to receive(:user_error!)
    end

    it 'returns true when pod push succeeds' do
      allow(Fastlane::Actions::PodPushAction).to receive(:run).and_return("Successfully pushed")

      result = Fastlane::Actions::PodPushWithErrorHandlingAction.run(path: podspec_path)

      expect(result).to eq(true)
      expect(Fastlane::Actions::PodPushAction).to have_received(:run).once
    end

    it 'catches duplicate entry error and returns false' do
      error_message = "[!] Unable to accept duplicate entry for: RevenueCat"
      allow(Fastlane::Actions::PodPushAction).to receive(:run).and_raise(StandardError.new(error_message))

      result = Fastlane::Actions::PodPushWithErrorHandlingAction.run(path: podspec_path)

      expect(result).to eq(false)
      expect(FastlaneCore::UI).to have_received(:error).with("⚠️ Duplicate entry detected. Skipping push.")
    end

    it 'raises a PodPushUnknownError for other failures' do
      error_message = "Some unexpected failure"
      allow(Fastlane::Actions::PodPushAction).to receive(:run).and_raise(StandardError.new(error_message))

      expect do
        Fastlane::Actions::PodPushWithErrorHandlingAction.run(path: podspec_path)
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

      expect(FastlaneCore::UI).to receive(:important).with(/Retrying in \d+ seconds/).exactly(3).times
      expect(FastlaneCore::UI).to receive(:message).with(/Attempt \d/).exactly(4).times # 3 failures + 1 success

      result = Fastlane::Actions::PodPushWithErrorHandlingAction.run(
        path: podspec_path,
        synchronous: true,
        verbose: false,
        allow_warnings: false
      )

      expect(result).to eq(true) # ✅ Ensure success on the 4th attempt
    end

    it 'retries up to 3 times on internal server error' do
      error_message = '[!] An internal server error occurred. Please check for any known status issues at https://twitter.com/CocoaPods and try again later.'
      call_count = 0
  
      allow(Fastlane::Actions::PodPushAction).to receive(:run) do
        call_count += 1
        raise StandardError, error_message if call_count <= 3
  
        'Successfully pushed' # ✅ Succeed on the 4th attempt
      end
  
      expect(FastlaneCore::UI).to receive(:important).with(/Retrying in \d+ seconds/).exactly(3).times
      expect(FastlaneCore::UI).to receive(:message).with(/Attempt \d/).exactly(4).times # 3 failures + 1 success
  
      result = Fastlane::Actions::PodPushWithErrorHandlingAction.run(
        path: podspec_path,
        synchronous: true,
        verbose: false,
        allow_warnings: false
      )
  
      expect(result).to eq(true) # ✅ Ensure success on the 4th attempt
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
