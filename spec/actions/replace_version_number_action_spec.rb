describe Fastlane::Actions::ReplaceVersionNumberAction do
  describe '#run' do
    it 'replaces old version with new version in passed files' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file.sh').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file2.rb').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file3.kt').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file4.swift').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0',
        new_version_number: '1.13.0',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
      )
    end

    it 'replaces old version with new version in passed files including prerelease modifiers and no prerelease modifiers' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0-SNAPSHOT|', './test_file.sh').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0-SNAPSHOT|', './test_file2.rb').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file3.kt').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file4.swift').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0-SNAPSHOT',
        new_version_number: '1.13.0-SNAPSHOT',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
      )
    end

    it 'replaces old version with new version in passed files when old version has prerelease modifiers' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0|', './test_file.sh').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0|', './test_file2.rb').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file3.kt').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file4.swift').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0-SNAPSHOT',
        new_version_number: '1.13.0',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
      )
    end

    it 'replaces old version with new version in passed files when new version has prerelease modifiers' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0-SNAPSHOT|', './test_file.sh').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0-SNAPSHOT|', './test_file2.rb').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file3.kt').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file4.swift').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0',
        new_version_number: '1.13.0-SNAPSHOT',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
      )
    end

    it 'replaces old version with new version in passed files when files to update without prerelease modifiers is empty' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0-SNAPSHOT|', './test_file.sh').once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0-SNAPSHOT|', './test_file2.rb').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0',
        new_version_number: '1.13.0-SNAPSHOT',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: []
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::ReplaceVersionNumberAction.available_options.size).to eq(4)
    end
  end
end
