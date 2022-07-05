describe Fastlane::Helper::RevenuecatHelper do
  describe '.replace_version_number' do
    let(:file_to_update_1) { './test_files/file_to_update_1.txt' }
    let(:file_to_update_2) { './test_files/file_to_update_2.txt' }
    let(:file_to_update_without_prerelease_modifiers_3) { './test_files/file_to_update_3.txt' }
    let(:file_to_update_without_prerelease_modifiers_4) { './test_files/file_to_update_4.txt' }

    it 'updates previous version number with new version number when no prerelease modifiers are passed' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_1).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_2).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_3).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_4).once

      Fastlane::Helper::RevenuecatHelper.replace_version_number('1.11.0',
                                                                '1.12.0',
                                                                [file_to_update_1,
                                                                 file_to_update_2],
                                                                [file_to_update_without_prerelease_modifiers_3,
                                                                 file_to_update_without_prerelease_modifiers_4])
    end

    it 'updates previous version number with new version number when current version has prerelease modifiers' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0-SNAPSHOT|1.12.0|', file_to_update_1).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0-SNAPSHOT|1.12.0|', file_to_update_2).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_3).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_4).once

      Fastlane::Helper::RevenuecatHelper.replace_version_number('1.11.0-SNAPSHOT',
                                                                '1.12.0',
                                                                [file_to_update_1,
                                                                 file_to_update_2],
                                                                [file_to_update_without_prerelease_modifiers_3,
                                                                 file_to_update_without_prerelease_modifiers_4])
    end

    it 'updates previous version number with new version number when new version has prerelease modifiers' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0-SNAPSHOT|', file_to_update_1).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0-SNAPSHOT|', file_to_update_2).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_3).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_4).once

      Fastlane::Helper::RevenuecatHelper.replace_version_number('1.11.0',
                                                                '1.12.0-SNAPSHOT',
                                                                [file_to_update_1,
                                                                 file_to_update_2],
                                                                [file_to_update_without_prerelease_modifiers_3,
                                                                 file_to_update_without_prerelease_modifiers_4])
    end
  end

  describe '.auto_generate_changelog' do
    it 'generates changelog automatically from github commits' do
      Fastlane::Helper::RevenuecatHelper.auto_generate_changelog('mock-repo-name',
                                                                 nil,
                                                                 nil,
                                                                 0,
                                                                 false)
    end
  end
end
