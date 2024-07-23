describe Fastlane::Actions::UpdateHybridsVersionsFileAction do
  describe '#run' do
    let(:versions_path) { './tmp_test_files/test_versions.md' }
    let(:hybrid_common_version) { '1.1.0' }

    require 'fileutils'

    before(:each) do
      Dir.mkdir('tmp_test_files')
    end

    after(:each) do
      FileUtils.rm_rf('tmp_test_files')
    end

    it 'updates versions file with correct versions' do
      initial_value = "| Version | iOS version | Android version | common version | Play Billing Library version |\n" \
                      "------------------------------------------------------------------------------------------|\n" \
                      "| 1.5.0 | 1.3.5 | 2.1.1 | 1.0.8 | |\n" \
                      "| 1.0.0 | 1.3.4 | 2.0.1 | 1.0.5 | |\n"
      File.write(versions_path, initial_value)
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('2.1.2').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_ios_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('1.4.1').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_billing_client_version)
        .with('2.1.2').and_return('6.2.1').once
      Fastlane::Actions::UpdateHybridsVersionsFileAction.run(
        versions_file_path: versions_path,
        new_sdk_version: '1.5.1',
        hybrid_common_version: hybrid_common_version
      )
      updated_versions_content = File.read(versions_path)
      expected_content = "| Version | iOS version | Android version | common version | Play Billing Library version |\n" \
                         "------------------------------------------------------------------------------------------|\n" \
                         "| 1.5.1 | [1.4.1](https://github.com/RevenueCat/purchases-ios/releases/tag/1.4.1) | [2.1.2](https://github.com/RevenueCat/purchases-android/releases/tag/2.1.2) | [1.1.0](https://github.com/RevenueCat/purchases-hybrid-common/releases/tag/1.1.0) | [6.2.1](https://developer.android.com/google/play/billing/release-notes) |\n" \
                         "| 1.5.0 | 1.3.5 | 2.1.1 | 1.0.8 | |\n" \
                         "| 1.0.0 | 1.3.4 | 2.0.1 | 1.0.5 | |\n"
      expect(updated_versions_content).to eq(expected_content)
    end

    it 'updates versions file with correct versions if android billing client column does not exist' do
      initial_value = "| Version | iOS version | Android version | common version |\n" \
                      "------------------------------------------------------------\n" \
                      "| 1.5.0 | 1.3.5 | 2.1.1 | 1.0.8 |\n" \
                      "| 1.0.0 | 1.3.4 | 2.0.1 | 1.0.5 |\n"
      File.write(versions_path, initial_value)
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('2.1.2').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_ios_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('1.4.1').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_billing_client_version)
        .with('2.1.2').and_return('6.2.1').once
      Fastlane::Actions::UpdateHybridsVersionsFileAction.run(
        versions_file_path: versions_path,
        new_sdk_version: '1.5.1',
        hybrid_common_version: hybrid_common_version
      )
      updated_versions_content = File.read(versions_path)
      expected_content = "| Version | iOS version | Android version | common version | Play Billing Library version |\n" \
                         "------------------------------------------------------------------------------------------|\n" \
                         "| 1.5.1 | [1.4.1](https://github.com/RevenueCat/purchases-ios/releases/tag/1.4.1) | [2.1.2](https://github.com/RevenueCat/purchases-android/releases/tag/2.1.2) | [1.1.0](https://github.com/RevenueCat/purchases-hybrid-common/releases/tag/1.1.0) | [6.2.1](https://developer.android.com/google/play/billing/release-notes) |\n" \
                         "| 1.5.0 | 1.3.5 | 2.1.1 | 1.0.8 | |\n" \
                         "| 1.0.0 | 1.3.4 | 2.0.1 | 1.0.5 | |\n"
      expect(updated_versions_content).to eq(expected_content)
    end

    it 'fails if versions file not found' do
      expect do |variable|
        Fastlane::Actions::UpdateHybridsVersionsFileAction.run(
          versions_file_path: './tmp_test_files/wront_test_versions.md',
          new_sdk_version: '1.5.1',
          hybrid_common_version: hybrid_common_version
        )
      end.to raise_exception(StandardError)
    end

    it 'works for no previous versions added' do
      initial_value = "| Version | iOS version | Android version | common version | Play Billing Library version |\n" \
                      "------------------------------------------------------------------------------------------|\n"
      File.write(versions_path, initial_value)
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('2.1.2').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_ios_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('1.4.1').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_billing_client_version)
        .with('2.1.2').and_return('6.2.1').once
      Fastlane::Actions::UpdateHybridsVersionsFileAction.run(
        versions_file_path: versions_path,
        new_sdk_version: '1.5.1',
        hybrid_common_version: hybrid_common_version
      )
      updated_versions_content = File.read(versions_path)
      expected_content = "| Version | iOS version | Android version | common version | Play Billing Library version |\n" \
                         "------------------------------------------------------------------------------------------|\n" \
                         "| 1.5.1 | [1.4.1](https://github.com/RevenueCat/purchases-ios/releases/tag/1.4.1) | [2.1.2](https://github.com/RevenueCat/purchases-android/releases/tag/2.1.2) | [1.1.0](https://github.com/RevenueCat/purchases-hybrid-common/releases/tag/1.1.0) | [6.2.1](https://developer.android.com/google/play/billing/release-notes) |\n"
      expect(updated_versions_content).to eq(expected_content)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::UpdateHybridsVersionsFileAction.available_options.size).to eq(3)
    end
  end
end
