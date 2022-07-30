describe Fastlane::Actions::ReplaceTextInFilesAction do
  describe '#run' do
    it 'calls appropriate helper with correct parameters for each given path' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_in)
        .with('old_text', 'new_text', './test_file.sh')
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_in)
        .with('old_text', 'new_text', './test_file2.rb')
        .once
      Fastlane::Actions::ReplaceTextInFilesAction.run(
        previous_text: 'old_text',
        new_text: 'new_text',
        paths_of_files_to_update: ['./test_file.sh', './test_file2.rb']
      )
    end

    it 'works when passing only 1 path' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_in)
        .with('old_text', 'new_text', './test_file.sh')
        .once
      Fastlane::Actions::ReplaceTextInFilesAction.run(
        previous_text: 'old_text',
        new_text: 'new_text',
        paths_of_files_to_update: ['./test_file.sh']
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::ReplaceTextInFilesAction.available_options.size).to eq(3)
    end
  end
end
