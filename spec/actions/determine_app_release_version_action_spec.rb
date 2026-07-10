describe Fastlane::Actions::DetermineAppReleaseVersionAction do
  describe '#run' do
    it 'calls the helper with the appropriate parameters' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:next_release_version)
        .with('mock-repo-name', 'mock-github-token', '1.2.0',
              major_bump_labels: ['pr:force_major'],
              minor_bump_labels: ['pr:feat'],
              patch_bump_labels: ['pr:fix'],
              changelog_ignore_label: 'pr:changelog_ignore')
        .and_return('1.3.0')
        .once

      version = Fastlane::Actions::DetermineAppReleaseVersionAction.run(
        repo_name: 'mock-repo-name',
        github_token: 'mock-github-token',
        current_version: '1.2.0',
        major_bump_labels: ['pr:force_major'],
        minor_bump_labels: ['pr:feat'],
        patch_bump_labels: ['pr:fix'],
        changelog_ignore_label: 'pr:changelog_ignore'
      )
      expect(version).to eq('1.3.0')
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::DetermineAppReleaseVersionAction.available_options.size).to eq(7)
    end

    it 'has the documented label defaults' do
      options = Fastlane::Actions::DetermineAppReleaseVersionAction.available_options
      defaults = options.to_h { |option| [option.key, option.default_value] }
      expect(defaults[:major_bump_labels]).to eq(['pr:force_major'])
      expect(defaults[:minor_bump_labels]).to eq(['pr:breaking', 'pr:feat', 'pr:force_minor'])
      expect(defaults[:patch_bump_labels]).to eq(['pr:fix', 'pr:dependencies', 'pr:force_patch'])
      expect(defaults[:changelog_ignore_label]).to eq('pr:changelog_ignore')
    end
  end
end
