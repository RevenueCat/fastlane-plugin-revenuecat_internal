describe Fastlane::Actions::BumpVersionUpdateChangelogCreatePRAction do
  describe '#run' do
    # it 'replaces old version with new version in passed files' do
    #   expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file.sh').once
    #   expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file2.rb').once
    #   expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file3.kt').once
    #   expect(Fastlane::Action).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.12.0|1.13.0|', './test_file4.swift').once
    #   Fastlane::Actions::ReplaceVersionNumberAction.run(
    #     current_version: '1.12.0',
    #     new_version: '1.13.0',
    #     files_to_update: ['./test_file.sh', './test_file2.rb'],
    #     files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift']
    #   )
    # end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::BumpVersionUpdateChangelogCreatePRAction.available_options.size).to eq(9)
    end

    # TODO: Add more tests for the options
  end
end
