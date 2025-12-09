describe Fastlane::Actions::ReplaceTextInFilesAction do
  describe '#run' do
    it 'calls appropriate helper with correct parameters for each given path' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_in)
        .with('old_text', 'new_text', './test_file.sh', allow_empty: true)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_in)
        .with('old_text', 'new_text', './test_file2.rb', allow_empty: true)
        .once
      Fastlane::Actions::ReplaceTextInFilesAction.run(
        previous_text: 'old_text',
        new_text: 'new_text',
        paths_of_files_to_update: ['./test_file.sh', './test_file2.rb'],
        allow_empty: true
      )
    end

    it 'works when passing only 1 path' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_in)
        .with('old_text', 'new_text', './test_file.sh', allow_empty: false)
        .once
      Fastlane::Actions::ReplaceTextInFilesAction.run(
        previous_text: 'old_text',
        new_text: 'new_text',
        paths_of_files_to_update: ['./test_file.sh'],
        allow_empty: false
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::ReplaceTextInFilesAction.available_options.size).to eq(5)
    end
  end

  describe '#run with skip_missing_files' do
    it 'skips missing files when skip_missing_files is true' do
      expect(File).to receive(:exist?).with('./missing_file.sh').and_return(false)
      expect(Fastlane::UI).to receive(:message).with('Skipping ./missing_file.sh - file does not exist')
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:replace_in)
      Fastlane::Actions::ReplaceTextInFilesAction.run(
        previous_text: 'old_text',
        new_text: 'new_text',
        paths_of_files_to_update: ['./missing_file.sh'],
        skip_missing_files: true
      )
    end

    it 'processes existing files when skip_missing_files is true' do
      expect(File).to receive(:exist?).with('./existing_file.sh').and_return(true)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_in)
        .with('old_text', 'new_text', './existing_file.sh', allow_empty: false)
        .once
      Fastlane::Actions::ReplaceTextInFilesAction.run(
        previous_text: 'old_text',
        new_text: 'new_text',
        paths_of_files_to_update: ['./existing_file.sh'],
        skip_missing_files: true
      )
    end

    it 'skips missing files but processes existing ones when skip_missing_files is true' do
      expect(File).to receive(:exist?).with('./missing_file.sh').and_return(false)
      expect(File).to receive(:exist?).with('./existing_file.sh').and_return(true)
      expect(Fastlane::UI).to receive(:message).with('Skipping ./missing_file.sh - file does not exist')
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_in)
        .with('old_text', 'new_text', './existing_file.sh', allow_empty: false)
        .once
      Fastlane::Actions::ReplaceTextInFilesAction.run(
        previous_text: 'old_text',
        new_text: 'new_text',
        paths_of_files_to_update: ['./missing_file.sh', './existing_file.sh'],
        skip_missing_files: true
      )
    end

    it 'does not check file existence when skip_missing_files is false' do
      expect(File).not_to receive(:exist?)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_in)
        .with('old_text', 'new_text', './test_file.sh', allow_empty: false)
        .once
      Fastlane::Actions::ReplaceTextInFilesAction.run(
        previous_text: 'old_text',
        new_text: 'new_text',
        paths_of_files_to_update: ['./test_file.sh'],
        skip_missing_files: false
      )
    end
  end
end
