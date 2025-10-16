describe Fastlane::Helper::RevenuecatInternalHelper do
  # rubocop:disable Naming/AccessorMethodName
  def get_latest_tag_command
    "git tag | grep '^[0-9]*.[0-9]*.[0-9]*$' | sort -r --version-sort | head -n1"
  end
  # rubocop:enable Naming/AccessorMethodName

  describe '.replace_version_number' do
    require 'fileutils'

    let(:file_to_update_1) { './tmp_test_files/file_to_update_1.txt' }
    let(:file_to_update_2) { './tmp_test_files/file_to_update_2.txt' }
    let(:file_to_update_without_prerelease_modifiers_3) { './tmp_test_files/file_to_update_3.txt' }
    let(:file_to_update_without_prerelease_modifiers_4) { './tmp_test_files/file_to_update_4.txt' }
    let(:file_to_update_on_latest_stable_release_5) { './tmp_test_files/file_to_update_5.txt' }

    before(:each) do
      allow(Fastlane::Actions).to receive(:sh).with("git fetch --tags -f")
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Dir.mkdir('./tmp_test_files')
    end

    after(:each) do
      FileUtils.rm_rf('./tmp_test_files')
    end

    it 'updates previous version number with new version number when no prerelease modifiers nor build metadata are passed' do
      File.write(file_to_update_1, 'Contains version: 1.11.0')
      File.write(file_to_update_2, 'Contains version: 1.11.0 and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0')
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0')

      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.11.0')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0',
        '1.12.0',
        { file_to_update_1 => ["{x}"], file_to_update_2 => ["{x}"] },
        { file_to_update_without_prerelease_modifiers_3 => ["{x}"], file_to_update_without_prerelease_modifiers_4 => ["{x}"] },
        { file_to_update_on_latest_stable_release_5 => ["{x}"] }
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0 and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.12.0')
    end

    it 'updates previous version number with new version number when current version has prerelease modifiers' do
      File.write(file_to_update_1, 'Contains version: 1.11.0 and version with snapshot: 1.11.0-SNAPSHOT')
      File.write(file_to_update_2, 'Contains version: 1.11.0-SNAPSHOT and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0')
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0')

      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0-SNAPSHOT',
        '1.12.0',
        { file_to_update_1 => ["{x}"], file_to_update_2 => ["{x}"] },
        { file_to_update_without_prerelease_modifiers_3 => ["{x}"], file_to_update_without_prerelease_modifiers_4 => ["{x}"] },
        { file_to_update_on_latest_stable_release_5 => ["{x}"] }
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.11.0 and version with snapshot: 1.12.0')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0 and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.12.0')
    end

    it 'updates previous version number with new version number when new version has prerelease modifiers' do
      File.write(file_to_update_1, 'Contains version: 1.11.0')
      File.write(file_to_update_2, 'Contains version: 1.11.0 and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0')
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0')

      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0',
        '1.12.0-SNAPSHOT',
        { file_to_update_1 => ["{x}"], file_to_update_2 => ["{x}"] },
        { file_to_update_without_prerelease_modifiers_3 => ["{x}"], file_to_update_without_prerelease_modifiers_4 => ["{x}"] },
        { file_to_update_on_latest_stable_release_5 => ["{x}"] }
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.12.0-SNAPSHOT')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0-SNAPSHOT and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.11.0')
    end

    it 'updates previous version number with new version number when current version has build metadata' do
      File.write(file_to_update_1, 'Contains version: 1.11.0 and version with build metadata: 1.11.0+1.2.3')
      File.write(file_to_update_2, 'Contains version: 1.11.0+1.2.3 and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0+1.2.3')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0+1.2.3')
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0+1.2.3')

      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0+1.2.3',
        '1.12.0',
        { file_to_update_1 => ["{x}"], file_to_update_2 => ["{x}"] },
        { file_to_update_without_prerelease_modifiers_3 => ["{x}"], file_to_update_without_prerelease_modifiers_4 => ["{x}"] },
        { file_to_update_on_latest_stable_release_5 => ["{x}"] }
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.11.0 and version with build metadata: 1.12.0')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0 and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.12.0')
    end

    it 'updates previous version number with new version number when new version has build metadata' do
      File.write(file_to_update_1, 'Contains version: 1.11.0')
      File.write(file_to_update_2, 'Contains version: 1.11.0 and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0')
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0')

      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0',
        '1.12.0+1.2.3',
        { file_to_update_1 => ["{x}"], file_to_update_2 => ["{x}"] },
        { file_to_update_without_prerelease_modifiers_3 => ["{x}"], file_to_update_without_prerelease_modifiers_4 => ["{x}"] },
        { file_to_update_on_latest_stable_release_5 => ["{x}"] }
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.12.0+1.2.3')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0+1.2.3 and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0+1.2.3')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0+1.2.3')
      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.12.0+1.2.3')
    end

    it 'updates previous version number with new version number when both versions have build metadata' do
      File.write(file_to_update_1, 'Contains version: 1.11.0+1.2.3')
      File.write(file_to_update_2, 'Contains version: 1.11.0+1.2.3 and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0+1.2.3')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0+1.2.3')
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0+1.2.3')

      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0+1.2.3',
        '1.12.0+1.2.4',
        { file_to_update_1 => ["{x}"], file_to_update_2 => ["{x}"] },
        { file_to_update_without_prerelease_modifiers_3 => ["{x}"], file_to_update_without_prerelease_modifiers_4 => ["{x}"] },
        { file_to_update_on_latest_stable_release_5 => ["{x}"] }
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.12.0+1.2.4')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0+1.2.4 and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0+1.2.4')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0+1.2.4')
      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.12.0+1.2.4')
    end

    it 'updates only version number that follows pattern' do
      File.write(file_to_update_1, 'Contains version: 1.11.0')
      File.write(file_to_update_2, 'Contains version: 1.11.0 and other version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0')
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0')

      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0',
        '1.12.0',
        { file_to_update_1 => ["{x}"], file_to_update_2 => ["Contains version: {x} and"] },
        { file_to_update_without_prerelease_modifiers_3 => ["{x}"], file_to_update_without_prerelease_modifiers_4 => ["{x}"] },
        { file_to_update_on_latest_stable_release_5 => ["{x}"] }
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0 and other version: 1.11.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.12.0')
    end

    it 'updates only version number that follows pattern when current version has prerelease modifiers' do
      File.write(file_to_update_1, 'Contains version: 1.11.0 and version with snapshot: 1.11.0-SNAPSHOT')
      File.write(file_to_update_2, 'Contains version: 1.11.0-SNAPSHOT and other version: 1.11.0-SNAPSHOT')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0 and other version: 1.11.0')
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0 and other version: 1.11.0')

      pattern = "Contains version: {x} and"
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0-SNAPSHOT',
        '1.12.0',
        {
            file_to_update_1 => ["{x}"],
            file_to_update_2 => [pattern]
        },
        {
            file_to_update_without_prerelease_modifiers_3 => ["{x}"],
            file_to_update_without_prerelease_modifiers_4 => [pattern]
        },
        {
            file_to_update_on_latest_stable_release_5 => [pattern]
        }
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.11.0 and version with snapshot: 1.12.0')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0 and other version: 1.11.0-SNAPSHOT')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0 and other version: 1.11.0')
      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.12.0 and other version: 1.11.0')
    end

    it 'updates only version number that follows pattern when new version has prerelease modifiers' do
      File.write(file_to_update_1, 'Contains version: 1.11.0')
      File.write(file_to_update_2, 'Contains version: 1.11.0 and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0 and other version: 1.11.0')
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0 and other version: 1.11.0')

      pattern = "Contains version: {x} and"
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0',
        '1.12.0-SNAPSHOT',
        { file_to_update_1 => ["{x}"], file_to_update_2 => [pattern] },
        {
            file_to_update_without_prerelease_modifiers_3 => ["{x}"],
            file_to_update_without_prerelease_modifiers_4 => [pattern]
        },
        {
            file_to_update_on_latest_stable_release_5 => [pattern]
        }
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.12.0-SNAPSHOT')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0-SNAPSHOT and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0 and other version: 1.11.0')
      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.11.0 and other version: 1.11.0')
    end

    it 'does not update files on latest stable release if new version is prerelease' do
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.11.0')
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0',
        '1.12.0-SNAPSHOT',
        {},
        {},
        {
          file_to_update_on_latest_stable_release_5 => ["{x}"]
        }
      )

      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.11.0')
    end

    it 'does not update files on latest stable release if new version is older than latest version' do
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.1.0')
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.1.0',
        '1.1.8',
        {},
        {},
        {
          file_to_update_on_latest_stable_release_5 => ["{x}"]
        }
      )

      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.1.0')
    end

    it 'does update files on latest stable release if new version is newer than latest version' do
      File.write(file_to_update_on_latest_stable_release_5, 'Contains version: 1.2.3')
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.2.3',
        '1.2.4',
        {},
        {},
        {
          file_to_update_on_latest_stable_release_5 => ["{x}"]
        }
      )

      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq('Contains version: 1.2.4')
    end

    it 'does update files on latest stable release if previous version does not match previous version given' do
      original_text = '<meta http-equiv="refresh" content="0; url=https://sdk.revenuecat.com/android/7.10.7/index.html" />'
      expected_text = '<meta http-equiv="refresh" content="0; url=https://sdk.revenuecat.com/android/1.2.4/index.html" />'

      File.write(file_to_update_on_latest_stable_release_5, original_text)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.2.3',
        '1.2.4',
        {},
        {},
        {
          file_to_update_on_latest_stable_release_5 => ["url=https://sdk.revenuecat.com/android/{x}/index.html"]
        }
      )

      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq(expected_text)
    end

    it 'does not update files on latest stable release if old version does not match a stable semver version' do
      original_text = '<meta http-equiv="refresh" content="0; url=https://sdk.revenuecat.com/android/7.10.7-SNAPSHOT/index.html" />'

      File.write(file_to_update_on_latest_stable_release_5, original_text)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.2.3',
        '1.2.4',
        {},
        {},
        {
          file_to_update_on_latest_stable_release_5 => ["url=https://sdk.revenuecat.com/android/{x}/index.html"]
        }
      )

      expect(File.read(file_to_update_on_latest_stable_release_5)).to eq(original_text)
    end

    it 'handles version numbers with trailing newlines (like from .version files)' do
      File.write(file_to_update_1, 'return "7.1.1"')
      File.write(file_to_update_2, '"version": "7.1.1"')

      # Simulate version read from .version file with trailing newline
      version_with_newline = "7.1.1\n"
      new_version = '7.2.0'

      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('7.0.0')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        version_with_newline,
        new_version,
        { file_to_update_1 => ['return "{x}"'], file_to_update_2 => ['"version": "{x}"'] },
        {},
        {}
      )

      expect(File.read(file_to_update_1)).to eq('return "7.2.0"')
      expect(File.read(file_to_update_2)).to eq('"version": "7.2.0"')
    end

    it 'handles version numbers with trailing whitespace and newlines' do
      File.write(file_to_update_1, 'PLUGIN_VERSION = "5.1.0"')

      # Simulate version read from file with various whitespace
      version_with_whitespace = "  5.1.0\n\t  "
      new_version = '  5.2.0  ' # Also test new version with whitespace

      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('5.0.0')
      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        version_with_whitespace,
        new_version,
        { file_to_update_1 => ['PLUGIN_VERSION = "{x}"'] },
        {},
        {}
      )

      expect(File.read(file_to_update_1)).to eq('PLUGIN_VERSION = "5.2.0"')
    end
  end

  describe '.newer_than_or_equal_to_latest_published_version?' do
    before(:each) do
      allow(Fastlane::Actions).to receive(:sh).with("git fetch --tags -f")
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
    end

    it 'if no tag is returned its considered latest' do
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.0.0')).to be_truthy
    end

    it 'returns false if tag older than latest' do
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.0.0')).to eq(false)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.0.0+3.2.1')).to eq(false)
    end

    it 'returns true if tag same as latest' do
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.2.3')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.2.3+3.2.1')).to eq(true)
    end

    it 'returns true if tag newer than latest' do
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.2.4')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.3.0')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('2.0.0')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.2.4+3.2.1')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.3.0+3.2.1')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('2.0.0+3.2.1')).to eq(true)
    end

    it 'returns false if tag older than latest when latest contains build metadata' do
      allow(Fastlane::Actions).to receive(:sh).with("git fetch --tags -f")
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')

      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.0.0')).to eq(false)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.0.0+1.2.3')).to eq(false)
    end

    it 'returns true if tag same as latest when latest contains build metadata' do
      allow(Fastlane::Actions).to receive(:sh).with("git fetch --tags -f")
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')

      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.2.3')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.2.3+1.2.3')).to eq(true)
    end

    it 'returns true if tag newer than latest when latest contains build metadata' do
      allow(Fastlane::Actions).to receive(:sh).with("git fetch --tags -f")
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')

      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.2.4')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.3.0')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('2.0.0')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.2.4+1.2.3')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('1.3.0+1.2.3')).to eq(true)
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.2.3+3.2.1')
      expect(Fastlane::Helper::RevenuecatInternalHelper.newer_than_or_equal_to_latest_published_version?('2.0.0+1.2.3')).to eq(true)
    end
  end

  describe '.edit_changelog' do
    let(:prepopulated_changelog) { 'mock prepopulated changelog' }
    let(:changelog_latest_path) { './mock-path/CHANGELOG.latest.md' }
    let(:editor) { 'vim' }

    before(:each) do
      allow(File).to receive(:read).with(changelog_latest_path).and_return('edited changelog')
      allow(File).to receive(:write).with(changelog_latest_path, prepopulated_changelog)
      allow(FastlaneCore::UI).to receive(:confirm).with('Open CHANGELOG.latest.md in \'vim\'? (No will quit this process)').and_return(true)
      allow_any_instance_of(Object).to receive(:system).with(editor, changelog_latest_path)
    end

    it 'writes prepopulated changelog to latest changelog file' do
      expect(File).to receive(:write).with(changelog_latest_path, prepopulated_changelog).once
      Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
    end

    it 'opens editor to edit prepopulated changelog' do
      expect_any_instance_of(Object).to receive(:system).with(editor, changelog_latest_path).once
      Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
    end

    it 'does not fail if prepopulated changelog is empty' do
      expect(File).to receive(:write)
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.edit_changelog('', changelog_latest_path, editor)
      end.not_to raise_exception(StandardError)
    end

    it 'fails if user cancels on confirmation to open editor' do
      expect(File).not_to receive(:write)
      allow(FastlaneCore::UI).to receive(:confirm).with('Open CHANGELOG.latest.md in \'vim\'? (No will quit this process)').and_return(false)
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
      end.to raise_exception(StandardError)
    end

    it 'asks for confirmation if prepopulated changelog remains the same after editor opening' do
      allow(File).to receive(:read).with(changelog_latest_path).and_return(prepopulated_changelog)
      expect(FastlaneCore::UI).to receive(:confirm)
        .with('You may have opened the changelog in a visual editor. Enter \'y\' when changes are saved or \'n\' to cancel').and_return(true).once
      Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
    end

    it 'fails if confirmation if prepopulated changelog remains the same after editor opening' do
      allow(File).to receive(:read).with(changelog_latest_path).and_return(prepopulated_changelog)
      expect(FastlaneCore::UI).to receive(:confirm)
        .with('You may have opened the changelog in a visual editor. Enter \'y\' when changes are saved or \'n\' to cancel').and_return(false).once
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
      end.to raise_exception(StandardError)
    end
  end

  describe '.write_changelog' do
    let(:prepopulated_changelog) { 'mock prepopulated changelog' }
    let(:changelog_latest_path) { './tmp_test_files/CHANGELOG.latest.md' }

    before(:each) do
      Dir.mkdir('./tmp_test_files')
      File.write(changelog_latest_path, 'Old changelog')
    end

    after(:each) do
      FileUtils.rm_rf('./tmp_test_files')
    end

    it 'writes prepopulated changelog to latest changelog file' do
      Fastlane::Helper::RevenuecatInternalHelper.write_changelog(prepopulated_changelog, changelog_latest_path)
      expect(File.read(changelog_latest_path)).to eq("#{prepopulated_changelog}\n")
    end

    it 'fails if prepopulated changelog is empty' do
      expect(File).not_to receive(:write)
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.write_changelog('', changelog_latest_path)
      end.to raise_exception(StandardError)
    end
  end

  describe '.attach_changelog_to_main' do
    require 'fileutils'

    let(:version_number) { '1.12.0' }
    let(:tmp_test_files_path) { './tmp_test_files' }
    let(:changelog_latest_path) { './tmp_test_files/CHANGELOG.latest.md' }
    let(:changelog_path) { './tmp_test_files/CHANGELOG.md' }

    before(:each) do
      Dir.mkdir(tmp_test_files_path)
      File.write(changelog_latest_path, 'changelog latest contents')
      File.write(changelog_path, "## 1.11.0\nchangelog contents")
    end

    after(:each) do
      FileUtils.rm_rf(tmp_test_files_path)
    end

    it 'prepends changelog latest file contents to changelog file' do
      Fastlane::Helper::RevenuecatInternalHelper.attach_changelog_to_main(version_number, changelog_latest_path, changelog_path)
      changelog_contents = File.read(changelog_path)
      expect(changelog_contents).to eq("## 1.12.0\nchangelog latest contents\n## 1.11.0\nchangelog contents")
    end
  end

  describe '.insert_old_version_changelog_in_current_branch' do
    require 'fileutils'

    let(:tmp_test_files_path) { './tmp_test_files' }
    let(:changelog_path) { './tmp_test_files/CHANGELOG.md' }

    before(:each) do
      Dir.mkdir(tmp_test_files_path)
    end

    after(:each) do
      FileUtils.rm_rf(tmp_test_files_path)
    end

    it 'inserts older version changelog in correct position between newer and older versions' do
      existing_changelog = "## 1.12.0\nLatest changes\n\n## 1.10.0\nOlder changes\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.11.0'
      changelog_content = "* Bug fixes\n* Performance improvements\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "## 1.12.0\nLatest changes\n\n## 1.11.0\n* Bug fixes\n* Performance improvements\n\n## 1.10.0\nOlder changes\n"
      expect(result).to eq(expected)
    end

    it 'inserts version at the beginning when it is newer than all existing versions' do
      existing_changelog = "## 1.10.0\nOlder changes\n\n## 1.9.0\nEven older changes\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.11.0'
      changelog_content = "* New features\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "## 1.11.0\n* New features\n\n## 1.10.0\nOlder changes\n\n## 1.9.0\nEven older changes\n"
      expect(result).to eq(expected)
    end

    it 'appends version at the end when it is older than all existing versions' do
      existing_changelog = "## 1.12.0\nLatest changes\n\n## 1.11.0\nRecent changes\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.10.0'
      changelog_content = "* Old bug fixes\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "## 1.12.0\nLatest changes\n\n## 1.11.0\nRecent changes\n## 1.10.0\n* Old bug fixes\n\n"
      expect(result).to eq(expected)
    end

    it 'handles empty changelog file' do
      File.write(changelog_path, "")

      version_to_insert = '1.10.0'
      changelog_content = "* Initial release\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "\n## 1.10.0\n* Initial release\n\n"
      expect(result).to eq(expected)
    end

    it 'handles changelog with only a header' do
      existing_changelog = "# CHANGELOG\n\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.0.0'
      changelog_content = "* First version\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "# CHANGELOG\n\n## 1.0.0\n* First version\n\n"
      expect(result).to eq(expected)
    end

    it 'fails when version already exists in changelog' do
      existing_changelog = "## 1.11.0\nExisting content\n\n## 1.10.0\nOlder changes\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.11.0'
      changelog_content = "* Duplicate version"

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with("Changelog already contains an entry for version #{version_to_insert}")
        .and_call_original

      expect do
        Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
          version_to_insert,
          changelog_content,
          changelog_path
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError)
    end

    it 'handles versions with build metadata correctly' do
      existing_changelog = "## 1.12.0\nLatest changes\n\n## 1.10.0\nOlder changes\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.11.0+4.5.3'
      changelog_content = "* Version with build metadata\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "## 1.12.0\nLatest changes\n\n## 1.11.0+4.5.3\n* Version with build metadata\n\n## 1.10.0\nOlder changes\n"
      expect(result).to eq(expected)
    end

    it 'handles versions with prerelease identifiers correctly' do
      existing_changelog = "## 1.12.0\nLatest changes\n\n## 1.10.0\nOlder changes\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.11.0-beta.1'
      changelog_content = "* Beta version\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "## 1.12.0\nLatest changes\n\n## 1.11.0-beta.1\n* Beta version\n\n## 1.10.0\nOlder changes\n"
      expect(result).to eq(expected)
    end

    it 'compares versions by core version ignoring build metadata' do
      existing_changelog = "## 1.12.0+3.2.1\nLatest changes\n\n## 1.10.0\nOlder changes\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.11.0+4.5.3'
      changelog_content = "* Middle version\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "## 1.12.0+3.2.1\nLatest changes\n\n## 1.11.0+4.5.3\n* Middle version\n\n## 1.10.0\nOlder changes\n"
      expect(result).to eq(expected)
    end

    it 'handles major version differences correctly' do
      existing_changelog = "## 2.0.0\nMajor release\n\n## 1.12.0\nOld major version\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.13.0'
      changelog_content = "* Last version of v1\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "## 2.0.0\nMajor release\n\n## 1.13.0\n* Last version of v1\n\n## 1.12.0\nOld major version\n"
      expect(result).to eq(expected)
    end

    it 'handles complex changelog with multiple versions correctly' do
      existing_changelog = "# CHANGELOG\n\n## 1.15.0\nNewest\n\n## 1.13.0\nMiddle newer\n\n## 1.11.0\nMiddle\n\n## 1.9.0\nOldest\n"
      File.write(changelog_path, existing_changelog)

      version_to_insert = '1.12.0'
      changelog_content = "* Fits between 1.13.0 and 1.11.0\n"

      Fastlane::Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_current_branch(
        version_to_insert,
        changelog_content,
        changelog_path
      )

      result = File.read(changelog_path)
      expected = "# CHANGELOG\n\n## 1.15.0\nNewest\n\n## 1.13.0\nMiddle newer\n\n## 1.12.0\n* Fits between 1.13.0 and 1.11.0\n\n## 1.11.0\nMiddle\n\n## 1.9.0\nOldest\n"
      expect(result).to eq(expected)
    end
  end

  describe '.create_new_branch_and_checkout' do
    it 'creates new release branch with version number' do
      expect(Fastlane::Actions).to receive(:sh).with("git checkout -b 'fake-branch'")
      Fastlane::Helper::RevenuecatInternalHelper.create_new_branch_and_checkout('fake-branch')
    end
  end

  describe '.create_or_checkout_branch' do
    let(:branch_name) { 'test-branch' }

    it 'creates a new branch when it does not exist locally or remotely' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "branch", "--list", branch_name).and_return("")
      allow(Fastlane::Actions).to receive(:sh).with("git", "ls-remote", "--heads", "origin", branch_name).and_return("")
      allow(FastlaneCore::UI).to receive(:message)

      expect(FastlaneCore::UI).to receive(:message).with("Creating new branch #{branch_name}").once
      expect(Fastlane::Actions).to receive(:sh).with("git checkout -b '#{branch_name}'").once

      Fastlane::Helper::RevenuecatInternalHelper.create_or_checkout_branch(branch_name)
    end

    it 'checks out existing branch when it exists locally but not remotely' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "branch", "--list", branch_name).and_return(branch_name)
      allow(Fastlane::Actions).to receive(:sh).with("git", "ls-remote", "--heads", "origin", branch_name).and_return("")
      allow(FastlaneCore::UI).to receive(:message)

      expect(FastlaneCore::UI).to receive(:message).with("Branch #{branch_name} already exists, checking it out").once
      expect(Fastlane::Actions).to receive(:sh).with("git checkout '#{branch_name}'").once
      expect(Fastlane::Actions).not_to receive(:sh).with("git pull 'origin' '#{branch_name}'")

      Fastlane::Helper::RevenuecatInternalHelper.create_or_checkout_branch(branch_name)
    end

    it 'checks out and pulls when branch exists remotely but not locally' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "branch", "--list", branch_name).and_return("")
      allow(Fastlane::Actions).to receive(:sh).with("git", "ls-remote", "--heads", "origin", branch_name).and_return("refs/heads/#{branch_name}")
      allow(FastlaneCore::UI).to receive(:message)

      expect(FastlaneCore::UI).to receive(:message).with("Branch #{branch_name} already exists, checking it out").once
      expect(Fastlane::Actions).to receive(:sh).with("git checkout '#{branch_name}'").once
      expect(Fastlane::Actions).to receive(:sh).with("git pull 'origin' '#{branch_name}'").once

      Fastlane::Helper::RevenuecatInternalHelper.create_or_checkout_branch(branch_name)
    end

    it 'checks out and pulls when branch exists both locally and remotely' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "branch", "--list", branch_name).and_return(branch_name)
      allow(Fastlane::Actions).to receive(:sh).with("git", "ls-remote", "--heads", "origin", branch_name).and_return("refs/heads/#{branch_name}")
      allow(FastlaneCore::UI).to receive(:message)

      expect(FastlaneCore::UI).to receive(:message).with("Branch #{branch_name} already exists, checking it out").once
      expect(Fastlane::Actions).to receive(:sh).with("git checkout '#{branch_name}'").once
      expect(Fastlane::Actions).to receive(:sh).with("git pull 'origin' '#{branch_name}'").once

      Fastlane::Helper::RevenuecatInternalHelper.create_or_checkout_branch(branch_name)
    end
  end

  describe '.commmit_changes_and_push_current_branch' do
    before(:each) do
      allow(Fastlane::Actions).to receive(:sh).with(anything)
      allow(Fastlane::Actions::PushToGitRemoteAction).to receive(:run).with(remote: 'origin')
    end

    it 'stages files' do
      expect(Fastlane::Actions).to receive(:sh).with('git add -u').once
      Fastlane::Helper::RevenuecatInternalHelper.commit_changes_and_push_current_branch('Fastlane test commit message')
    end

    it 'commits files with correct message' do
      expect(Fastlane::Actions).to receive(:sh).with("git commit -m 'Fastlane test commit message'").once
      Fastlane::Helper::RevenuecatInternalHelper.commit_changes_and_push_current_branch('Fastlane test commit message')
    end

    it 'pushes to remote' do
      expect(Fastlane::Actions::PushToGitRemoteAction).to receive(:run).with(remote: 'origin').once
      Fastlane::Helper::RevenuecatInternalHelper.commit_changes_and_push_current_branch('Fastlane test commit message')
    end
  end

  describe '.create_pr' do
    it 'creates pr' do
      expect(Fastlane::Actions::CreatePullRequestAction).to receive(:run)
        .with(
          api_token: 'fake-github-pr-token',
          title: 'fake-title',
          base: 'main',
          body: 'fake-changelog',
          repo: 'RevenueCat/fake-repo-name',
          head: 'fake-branch',
          api_url: 'https://api.github.com',
          labels: ['label_1', 'label_2'],
          team_reviewers: ['coresdk']
        ).once
      Fastlane::Helper::RevenuecatInternalHelper.create_pr('fake-title', 'fake-changelog', 'fake-repo-name', 'main', 'fake-branch', 'fake-github-pr-token', ['label_1', 'label_2'])
    end
  end

  describe '.create_pr_if_necessary' do
    let(:title) { 'Test PR Title' }
    let(:body) { 'Test PR Body' }
    let(:repo_name) { 'test-repo' }
    let(:base_branch) { 'main' }
    let(:head_branch) { 'feature-branch' }
    let(:github_pr_token) { 'fake-github-token' }
    let(:labels) { ['label1', 'label2'] }
    let(:team_reviewers) { ['team1', 'team2'] }
    let(:repo_with_owner) { "RevenueCat/#{repo_name}" }

    it 'creates a PR when no matching PR exists' do
      # Mock the API call to check for existing PRs
      expect(Fastlane::Actions::GithubApiAction).to receive(:run).with(
        api_token: github_pr_token,
        path: "/repos/#{repo_with_owner}/pulls?head=RevenueCat:#{head_branch}&state=open"
      ).and_return({ json: [] })

      # Mock the create PR action
      expect(Fastlane::Actions::CreatePullRequestAction).to receive(:run).with(
        repo: repo_with_owner,
        title: title,
        body: body,
        base: base_branch,
        head: head_branch,
        api_token: github_pr_token,
        labels: labels,
        team_reviewers: team_reviewers
      ).and_return('https://github.com/RevenueCat/test-repo/pull/123')

      Fastlane::Helper::RevenuecatInternalHelper.create_pr_if_necessary(
        title, body, repo_name, base_branch, head_branch, github_pr_token, labels, team_reviewers
      )
    end

    it 'does not create a PR when a matching PR already exists' do
      # Mock the API call to check for existing PRs - return a PR
      expect(Fastlane::Actions::GithubApiAction).to receive(:run).with(
        api_token: github_pr_token,
        path: "/repos/#{repo_with_owner}/pulls?head=RevenueCat:#{head_branch}&state=open"
      ).and_return({ json: [{ number: 123, html_url: 'https://github.com/RevenueCat/test-repo/pull/123' }] })

      # The create PR action should not be called
      expect(Fastlane::Actions::CreatePullRequestAction).not_to receive(:run)

      # Expect a UI message
      expect(FastlaneCore::UI).to receive(:message).with("PR already exists.")

      Fastlane::Helper::RevenuecatInternalHelper.create_pr_if_necessary(
        title, body, repo_name, base_branch, head_branch, github_pr_token, labels, team_reviewers
      )
    end

    it 'raises an error when PR creation fails' do
      # Mock the API call to check for existing PRs
      expect(Fastlane::Actions::GithubApiAction).to receive(:run).with(
        api_token: github_pr_token,
        path: "/repos/#{repo_with_owner}/pulls?head=RevenueCat:#{head_branch}&state=open"
      ).and_return({ json: [] })

      # Mock the create PR action to return nil (failure)
      expect(Fastlane::Actions::CreatePullRequestAction).to receive(:run).with(
        repo: repo_with_owner,
        title: title,
        body: body,
        base: base_branch,
        head: head_branch,
        api_token: github_pr_token,
        labels: labels,
        team_reviewers: team_reviewers
      ).and_return(nil)

      # Expect an error to be raised
      expect(FastlaneCore::UI).to receive(:user_error!).with("Failed to create pull request.")

      Fastlane::Helper::RevenuecatInternalHelper.create_pr_if_necessary(
        title, body, repo_name, base_branch, head_branch, github_pr_token, labels, team_reviewers
      )
    end
  end

  describe '.validate_local_config_status_for_bump' do
    before(:each) do
      allow(Fastlane::Actions).to receive(:sh).with('git', 'branch', '--list', 'new-branch').and_return('')
      allow(Fastlane::Actions).to receive(:sh).with('git', 'ls-remote', '--heads', 'origin', 'new-branch').and_return('')
      allow(Fastlane::Actions).to receive(:sh).with('git status --porcelain', { error_callback: anything, log: true }).and_return('')
      allow(Fastlane::Actions::EnsureGitStatusCleanAction).to receive(:run)
      allow(Fastlane::Actions::ResetGitRepoAction).to receive(:run).with(true)
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(false)
    end

    it 'fails if github_pr_token is nil' do
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', nil)
      end.to raise_exception(StandardError)
    end

    it 'fails if github_pr_token is empty' do
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', '')
      end.to raise_exception(StandardError)
    end

    it 'fails if new branch exists locally' do
      expect(Fastlane::Actions).to receive(:sh).with('git', 'branch', '--list', 'new-branch').and_return('new-branch').once
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', 'fake-github-pr-token')
      end.to raise_exception(StandardError)
    end

    it 'fails if new branch exists remotely' do
      expect(Fastlane::Actions).to receive(:sh)
        .with('git', 'ls-remote', '--heads', 'origin', 'new-branch')
        .and_return('59f7273ae446cef04eb402b9708f0772389c59c4  refs/heads/new-branch')
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', 'fake-github-pr-token')
      end.to raise_exception(StandardError)
    end

    it 'works if git returns ssh warning' do
      expect(Fastlane::Actions).to receive(:sh)
        .with('git', 'ls-remote', '--heads', 'origin', 'new-branch')
        .and_return("Warning: Permanently added the ECDSA host key for IP address 'xxx.xxx.xxx.xxx' to the list of known hosts.")
      Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', 'fake-github-pr-token')
    end

    it 'ensures new branch does not exist remotely' do
      expect(Fastlane::Actions).to receive(:sh).with('git', 'ls-remote', '--heads', 'origin', 'new-branch').once
      Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', 'fake-github-pr-token')
    end

    it 'ensures repo is in a clean state when running on local' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      expect(Fastlane::Actions::EnsureGitStatusCleanAction).to receive(:run).with({ show_diff: true }).once
      Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', 'fake-github-pr-token')
    end

    it 'doesnt ensure repo is clean when running on CI' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(false)
      expect(Fastlane::Actions::EnsureGitStatusCleanAction).to receive(:run).with({ show_diff: true }).never
      Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', 'fake-github-pr-token')
    end

    it 'resets repo when running on CI and there are changes' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(false)
      allow(Fastlane::Actions).to receive(:sh).with('git status --porcelain', { error_callback: anything, log: true })
                                              .and_return('M lib/fastlane/plugin/revenuecat_internal/actions/create_next_snapshot_version_action.rb')
      expect(Fastlane::Actions::ResetGitRepoAction).to receive(:run).with({ force: true }).once
      Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', 'fake-github-pr-token')
    end

    it 'doesnt reset repo when running on CI and there are no changes' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(false)
      expect(Fastlane::Actions::ResetGitRepoAction).to receive(:run).with({ force: true }).never
      Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('new-branch', 'fake-github-pr-token')
    end
  end

  describe '.calculate_next_snapshot_version' do
    it 'calculates next version correctly with version with hotfix' do
      next_version = Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('1.11.1')
      expect(next_version).to eq('1.12.0-SNAPSHOT')
    end

    it 'calculates next version correctly with prerelease version' do
      next_version = Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('1.11.1-alpha.1')
      expect(next_version).to eq('1.11.1-SNAPSHOT')
    end

    it 'calculates next version correctly with major relase' do
      next_version = Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('5.0.0')
      expect(next_version).to eq('5.1.0-SNAPSHOT')
    end

    it 'fails if given version without hotfix number' do
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('1.11')
      end.to raise_exception(StandardError)
    end

    it 'fails if given version with more than 3 numbers' do
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('1.11.1.1')
      end.to raise_exception(StandardError)
    end
  end

  describe '.create_github_release' do
    let(:commit_hash) { 'fake-commit-hash' }
    let(:release_description) { 'fake-description' }
    let(:upload_assets) { ['./path-to/upload-asset-1.txt', './path-to/upload-asset-2.rb'] }
    let(:repo_name) { 'fake-repo-name' }
    let(:github_api_token) { 'fake-github-api-token' }
    let(:no_prerelease_version) { '1.11.0' }
    let(:prerelease_version) { '1.11.0-SNAPSHOT' }
    let(:server_url) { 'https://api.github.com' }

    before(:each) do
      allow(Fastlane::Actions).to receive(:last_git_commit_dict).and_return(commit_hash: commit_hash)
    end

    it 'calls GitHubHelper with appropriate parameters for non-prerelease that is newer than existing version' do
      allow(Fastlane::Actions).to receive(:sh).with("git fetch --tags -f")
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.10.0')

      expect(Fastlane::Helper::GitHubHelper).to receive(:create_github_release).with(
        repository_name: "RevenueCat/fake-repo-name",
        api_token: github_api_token,
        name: no_prerelease_version,
        tag_name: no_prerelease_version,
        description: release_description,
        commitish: commit_hash,
        upload_assets: upload_assets,
        is_draft: false,
        is_prerelease: false,
        make_latest: true,
        server_url: server_url
      )
      Fastlane::Helper::RevenuecatInternalHelper.create_github_release(
        no_prerelease_version,
        release_description,
        upload_assets,
        repo_name,
        github_api_token
      )
    end

    it 'calls GitHubHelper with appropriate parameters for non-prerelease that is exactly the latest existing version' do
      allow(Fastlane::Actions).to receive(:sh).with("git fetch --tags -f")
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.11.0')

      # We expect make_latest to be true because the version is exactly the latest existing version
      # and create_github_release is executed right after the tag is created
      # (i.e. the latest tag matches the version we are releasing)

      expect(Fastlane::Helper::GitHubHelper).to receive(:create_github_release).with(
        repository_name: "RevenueCat/fake-repo-name",
        api_token: github_api_token,
        name: no_prerelease_version,
        tag_name: no_prerelease_version,
        description: release_description,
        commitish: commit_hash,
        upload_assets: upload_assets,
        is_draft: false,
        is_prerelease: false,
        make_latest: true,
        server_url: server_url
      )
      Fastlane::Helper::RevenuecatInternalHelper.create_github_release(
        no_prerelease_version,
        release_description,
        upload_assets,
        repo_name,
        github_api_token
      )
    end

    it 'calls GitHubHelper with appropriate parameters for non-prerelease that is older than existing version' do
      allow(Fastlane::Actions).to receive(:sh).with("git fetch --tags -f")
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('1.12.0')

      expect(Fastlane::Helper::GitHubHelper).to receive(:create_github_release).with(
        repository_name: "RevenueCat/fake-repo-name",
        api_token: github_api_token,
        name: no_prerelease_version,
        tag_name: no_prerelease_version,
        description: release_description,
        commitish: commit_hash,
        upload_assets: upload_assets,
        is_draft: false,
        is_prerelease: false,
        make_latest: false,
        server_url: server_url
      )
      Fastlane::Helper::RevenuecatInternalHelper.create_github_release(
        no_prerelease_version,
        release_description,
        upload_assets,
        repo_name,
        github_api_token
      )
    end

    it 'calls GitHubHelper with appropriate parameters for prerelease version' do
      allow(Fastlane::Actions).to receive(:sh).with("git fetch --tags -f")
      allow(Fastlane::Actions).to receive(:sh).with(get_latest_tag_command).and_return('')

      expect(Fastlane::Helper::GitHubHelper).to receive(:create_github_release).with(
        repository_name: "RevenueCat/fake-repo-name",
        api_token: github_api_token,
        name: prerelease_version,
        tag_name: prerelease_version,
        description: release_description,
        commitish: commit_hash,
        upload_assets: upload_assets,
        is_draft: false,
        is_prerelease: true,
        make_latest: false,
        server_url: server_url
      )
      Fastlane::Helper::RevenuecatInternalHelper.create_github_release(
        prerelease_version,
        release_description,
        upload_assets,
        repo_name,
        github_api_token
      )
    end
  end

  describe '.replace_in' do
    require 'fileutils'

    let(:tmp_test_file_path) { './tmp_test_files/test_file.txt' }

    before(:each) do
      Dir.mkdir('tmp_test_files')
    end

    after(:each) do
      FileUtils.rm_rf('tmp_test_files')
    end

    it 'fails if new string is empty and allow_empty false' do
      expect(Fastlane::Actions).not_to receive(:sh)
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.replace_in('1.11.0', '', tmp_test_file_path, allow_empty: false)
      end.to raise_exception(StandardError)
    end

    it 'changes old string with empty new string if allow_empty is true' do
      File.write(tmp_test_file_path, 'Testing removing=1.11.0, but not=1.11.1')
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('1.11.0', '', tmp_test_file_path, allow_empty: true)
      expect(File.read(tmp_test_file_path)).to eq('Testing removing=, but not=1.11.1')
    end

    it 'changes old string with new string' do
      File.write(tmp_test_file_path, 'Testing changing text=4.1.3-SNAPSHOT')
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('4.1.3-SNAPSHOT', '4.1.3', tmp_test_file_path)
      expect(File.read(tmp_test_file_path)).to eq('Testing changing text=4.1.3')
    end

    it 'changes multiple occurences of old string with new string' do
      File.write(tmp_test_file_path, "Testing changing text=4.1.3-SNAPSHOT and also\nversion=4.1.3-SNAPSHOT\nand again without spaces4.1.3-SNAPSHOT")
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('4.1.3-SNAPSHOT', '4.1.3', tmp_test_file_path)
      expect(File.read(tmp_test_file_path)).to eq("Testing changing text=4.1.3 and also\nversion=4.1.3\nand again without spaces4.1.3")
    end

    it 'does not change any text if old text not present in file' do
      contents = 'Testing 4.1.4'
      File.write(tmp_test_file_path, contents)
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('4.1.3', '4.4.0-SNAPSHOT', tmp_test_file_path)
      expect(File.read(tmp_test_file_path)).to eq(contents)
    end

    it 'does not change text that does not match exact old text with dots' do
      contents = '55413C0025B778E00ECCA5A'
      File.write(tmp_test_file_path, '55413C0025B778E00ECCA5A')
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('4.1.3', '4.4.0-SNAPSHOT', tmp_test_file_path)
      expect(File.read(tmp_test_file_path)).to eq(contents)
    end
  end

  describe '.commit_current_changes' do
    it 'calls appropriate actions with correct parameters' do
      expect(Fastlane::Actions).to receive(:sh).with('git add -u').once
      expect(Fastlane::Actions).to receive(:sh).with("git commit -m 'fake-commit-message'").once
      Fastlane::Helper::RevenuecatInternalHelper.commit_current_changes('fake-commit-message')
    end
  end

  describe '.commit_all_changes' do
    it 'stages all changes and commits with message' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "status", "--porcelain").and_return("M file.txt")
      allow(File).to receive(:basename).with(Dir.pwd).and_return("not-fastlane")

      expect(Fastlane::Actions).to receive(:sh).with("git", "add", "--all", ".").once
      expect(Fastlane::Actions).to receive(:sh).with("git", "commit", "-m", "fake-commit-message").once

      Fastlane::Helper::RevenuecatInternalHelper.commit_all_changes('fake-commit-message')
    end

    it 'does not commit when there are no changes' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "status", "--porcelain").and_return("")
      allow(FastlaneCore::UI).to receive(:message)

      expect(Fastlane::Actions).not_to receive(:sh).with("git", "add", "--all", ".")
      expect(Fastlane::Actions).not_to receive(:sh).with("git", "commit", "-m", "fake-commit-message")
      expect(FastlaneCore::UI).to receive(:message).with("No changes to commit").once

      Fastlane::Helper::RevenuecatInternalHelper.commit_all_changes('fake-commit-message')
    end

    it 'changes to parent directory when in fastlane directory' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "status", "--porcelain").and_return("M file.txt")
      allow(File).to receive(:basename).with(Dir.pwd).and_return("fastlane")

      expect(Dir).to receive(:chdir).with("..").and_yield.once
      expect(Fastlane::Actions).to receive(:sh).with("git", "add", "--all", ".").once
      expect(Fastlane::Actions).to receive(:sh).with("git", "commit", "-m", "fake-commit-message").once

      Fastlane::Helper::RevenuecatInternalHelper.commit_all_changes('fake-commit-message')
    end

    it 'stays in current directory when not in fastlane directory' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "status", "--porcelain").and_return("M file.txt")
      allow(File).to receive(:basename).with(Dir.pwd).and_return("src")

      expect(Dir).not_to receive(:chdir).with("..")
      expect(Fastlane::Actions).to receive(:sh).with("git", "add", "--all", ".").once
      expect(Fastlane::Actions).to receive(:sh).with("git", "commit", "-m", "fake-commit-message").once

      Fastlane::Helper::RevenuecatInternalHelper.commit_all_changes('fake-commit-message')
    end

    it 'commits untracked files unlike commit_current_changes' do
      # This test highlights a difference between commit_all_changes and commit_current_changes
      # git add --all . stages untracked files, while git add -u doesn't
      allow(Fastlane::Actions).to receive(:sh).with("git", "status", "--porcelain").and_return("?? new_file.txt")
      allow(File).to receive(:basename).with(Dir.pwd).and_return("not-fastlane")

      expect(Fastlane::Actions).to receive(:sh).with("git", "add", "--all", ".").once
      expect(Fastlane::Actions).to receive(:sh).with("git", "commit", "-m", "fake-commit-message").once

      Fastlane::Helper::RevenuecatInternalHelper.commit_all_changes('fake-commit-message')
    end
  end

  describe '.get_github_release_tag_names' do
    let(:repo_name) { 'purchases-ios' }
    let(:get_releases_purchases_ios_response) do
      { json: JSON.parse(File.read("#{File.dirname(__FILE__)}/../test_files/get_releases_purchases_ios.json")) }
    end

    it 'returns expected version numbers from response' do
      expect(Fastlane::Actions::GithubApiAction).to receive(:run).with(
        server_url: "https://api.github.com",
        http_method: 'GET',
        path: "repos/RevenueCat/purchases-ios/releases",
        api_token: 'mock-github-token',
        error_handlers: anything
      ).and_return(get_releases_purchases_ios_response).once
      tag_names = Fastlane::Helper::RevenuecatInternalHelper.get_github_release_tag_names(repo_name, 'mock-github-token')
      expect(tag_names.count).to eq(3)
      expect(tag_names).to include('4.9.1')
      expect(tag_names).to include('4.9.0')
      expect(tag_names).to include('5.10.0')
    end
  end
end
