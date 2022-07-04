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
  end
end
