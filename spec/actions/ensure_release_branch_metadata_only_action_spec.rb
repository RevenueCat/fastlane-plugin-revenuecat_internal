describe Fastlane::Actions::EnsureReleaseBranchMetadataOnlyAction do
  describe '#run' do
    it 'calls the helper with the appropriate parameters' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:ensure_release_branch_is_metadata_only!)
        .with('main', ['fastlane/metadata/'], 'App.xcodeproj/project.pbxproj', 'MARKETING_VERSION')
        .once

      Fastlane::Actions::EnsureReleaseBranchMetadataOnlyAction.run(
        main_branch: 'main',
        allowed_path_prefixes: ['fastlane/metadata/'],
        version_file: 'App.xcodeproj/project.pbxproj',
        version_line_pattern: 'MARKETING_VERSION'
      )
    end

    it 'allows omitting the version file entirely' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:ensure_release_branch_is_metadata_only!)
        .with('main', ['fastlane/metadata/'], nil, nil)
        .once

      Fastlane::Actions::EnsureReleaseBranchMetadataOnlyAction.run(
        main_branch: 'main',
        allowed_path_prefixes: ['fastlane/metadata/'],
        version_file: nil,
        version_line_pattern: nil
      )
    end

    it 'fails when a version file is given without a version line pattern' do
      expect do
        Fastlane::Actions::EnsureReleaseBranchMetadataOnlyAction.run(
          main_branch: 'main',
          allowed_path_prefixes: ['fastlane/metadata/'],
          version_file: 'App.xcodeproj/project.pbxproj',
          version_line_pattern: nil
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /version_line_pattern is required/)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::EnsureReleaseBranchMetadataOnlyAction.available_options.size).to eq(4)
    end
  end
end
