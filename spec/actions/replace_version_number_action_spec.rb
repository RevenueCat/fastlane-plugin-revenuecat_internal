describe Fastlane::Actions::ReplaceVersionNumberAction do
  describe '#run' do
    it 'calls appropriate helper with correct parameters' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with('1.12.0',
              '1.13.0',
              { './test_file.sh' => ['{x}'], './test_file2.rb' => ['{x}'] },
              { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] })
        .once
      Fastlane::Actions::ReplaceVersionNumberAction.run(
        current_version: '1.12.0',
        new_version_number: '1.13.0',
        files_to_update: { './test_file.sh' => ['{x}'], './test_file2.rb' => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] }
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::ReplaceVersionNumberAction.available_options.size).to eq(4)
    end
  end
end
