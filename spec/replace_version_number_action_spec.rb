describe Fastlane::Actions::ReplaceVersionNumberAction do
  describe '#run' do
    it 'replaces old version with new version in passed files' do
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file.sh').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file2.rb').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file3.kt').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file4.swift').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0',
        new_version: '1.13.0',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
      )
    end

    it 'replaces old version with new version in passed files including prerelease modifiers and no prerelease modifiers' do
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0-SNAPSHOT|', './test_file.sh').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0-SNAPSHOT|', './test_file2.rb').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file3.kt').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file4.swift').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0-SNAPSHOT',
        new_version: '1.13.0-SNAPSHOT',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
      )
    end

    it 'replaces old version with new version in passed files when old version has prerelease modifiers' do
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0|', './test_file.sh').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0|', './test_file2.rb').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file3.kt').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file4.swift').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0-SNAPSHOT',
        new_version: '1.13.0',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
      )
    end

    it 'replaces old version with new version in passed files when new version has prerelease modifiers' do
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0-SNAPSHOT|', './test_file.sh').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0-SNAPSHOT|', './test_file2.rb').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file3.kt').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file4.swift').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0',
        new_version: '1.13.0-SNAPSHOT',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
      )
    end

    it 'replaces old version with new version in passed files when files to update without prerelease modifiers is empty' do
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0-SNAPSHOT|', './test_file.sh').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0-SNAPSHOT|', './test_file2.rb').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0',
        new_version: '1.13.0-SNAPSHOT',
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: []
      )
    end

    it 'errors if current version param is missing' do
      expect(Fastlane::Action).not_to receive(:sh)
      expect do
        Fastlane::Actions::ReplaceVersionNumberAction.run(
          new_version: '1.13.0',
          files_to_update: ['./test_file.sh', './test_file2.rb'],
          files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
        )
      end.to raise_exception(StandardError)
    end

    it 'errors if new version param is missing' do
      expect(Fastlane::Action).not_to receive(:sh)
      expect do
        Fastlane::Actions::ReplaceVersionNumberAction.run(
          current_version: '1.12.0',
          files_to_update: ['./test_file.sh', './test_file2.rb'],
          files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
        )
      end.to raise_exception(StandardError)
    end

    it 'errors if files to update param is missing' do
      expect(Fastlane::Action).not_to receive(:sh)
      expect do
        Fastlane::Actions::ReplaceVersionNumberAction.run(
          current_version: '1.12.0',
          new_version: '1.13.0',
          files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
        )
      end.to raise_exception(StandardError)
    end

    it 'errors if files to update without prerelease modifiers param is missing' do
      expect(Fastlane::Action).not_to receive(:sh)
      expect do
        Fastlane::Actions::ReplaceVersionNumberAction.run(
          current_version: '1.12.0',
          new_version: '1.13.0',
          files_to_update: ['./test_file.sh', './test_file2.rb']
        )
      end.to raise_exception(StandardError)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::ReplaceVersionNumberAction.available_options.size).to eq(4)
    end

    # TODO: Add more tests for the options
  end
end
