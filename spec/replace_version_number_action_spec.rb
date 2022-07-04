describe Fastlane::Actions::ReplaceVersionNumberAction do
  describe '#run' do
    it 'replaces old version with new version in passed files' do
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file.sh').twice
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file2.rb').twice
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0',
        new_version: '1.13.0',
        files_to_update: ['./test_file.sh', './test_file2.rb']
      )
    end

    it 'replaces old version with new version in passed files including prerelease modifiers and no prerelease modifiers' do
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file.sh').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file2.rb').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0-SNAPSHOT|', './test_file.sh').once
      expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0-SNAPSHOT|1.13.0-SNAPSHOT|', './test_file2.rb').once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0-SNAPSHOT',
        new_version: '1.13.0-SNAPSHOT',
        files_to_update: ['./test_file.sh', './test_file2.rb']
      )
    end

    it 'errors if current version param is missing' do
      expect(Fastlane::Action).not_to receive(:sh)
      expect do
        Fastlane::Actions::ReplaceVersionNumberAction.run(
          new_version: '1.13.0',
          files_to_update: ['./test_file.sh', './test_file2.rb']
        )
      end.to raise_exception
    end
  end
end
