describe Fastlane::Actions::DerivedAppVersionAction do
  describe '#run' do
    it 'calls the helper with the appropriate parameters' do
      expect(Fastlane::Helper::AppReleaseTrainHelper).to receive(:derived_version)
        .with('1.2.0', 'main', 'mock-repo-name', 'mock-github-token',
              major_bump_labels: ['pr:force_major'],
              minor_bump_labels: ['pr:feat'],
              patch_bump_labels: ['pr:fix'],
              changelog_ignore_label: 'pr:changelog_ignore')
        .and_return('1.3.0')
        .once

      version = Fastlane::Actions::DerivedAppVersionAction.run(
        checked_in_version: '1.2.0',
        main_branch: 'main',
        repo_name: 'mock-repo-name',
        github_token: 'mock-github-token',
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
      expect(Fastlane::Actions::DerivedAppVersionAction.available_options.size).to eq(8)
    end

    it 'defaults main_branch to main' do
      option = Fastlane::Actions::DerivedAppVersionAction.available_options.find { |item| item.key == :main_branch }
      expect(option.default_value).to eq('main')
    end
  end
end
