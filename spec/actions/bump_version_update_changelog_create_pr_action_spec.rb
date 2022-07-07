describe Fastlane::Actions::BumpVersionUpdateChangelogCreatePRAction do
  describe '#run' do
    let(:mock_github_pr_token) { 'mock-github-pr-token' }
    let(:mock_github_token) { 'mock-github-token' }
    let(:mock_repo_name) { 'mock-repo-name' }
    let(:mock_changelog_latest_path) { './fake-changelog-latest-path/CHANGELOG.latest.md' }
    let(:mock_changelog_path) { './fake-changelog-path/CHANGELOG.md' }
    let(:branch) { 'main' }
    let(:editor) { 'vim' }
    let(:auto_generated_changelog) { 'mock-auto-generated-changelog' }
    let(:edited_changelog) { 'mock-edited-changelog' }
    let(:current_version) { '1.12.0' }
    let(:new_version) { '1.13.0' }

    before(:each) do
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump).with(anything)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:auto_generate_changelog).with(anything).and_return(auto_generated_changelog)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:edit_changelog).with(anything)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_release_branch).with(anything)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number).with(anything)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master).with(anything)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commmit_changes_and_push_current_branch).with(anything)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_release_pr).with(anything)
    end

    it 'calls all the appropriate methods with appropriate parameters' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump).with(branch).once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3)
        .and_return(auto_generated_changelog)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:edit_changelog)
        .with(auto_generated_changelog, mock_changelog_latest_path, editor)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_release_branch).with(new_version).once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, new_version, ['./test_file.sh', './test_file2.rb'], ['./test_file3.kt', './test_file4.swift'])
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master)
        .with(new_version, mock_changelog_latest_path, mock_changelog_path)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commmit_changes_and_push_current_branch)
        .with("Version bump for #{new_version}")
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_release_pr)
        .with(new_version, edited_changelog, mock_repo_name, mock_github_pr_token)
        .once

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePRAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift'],
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        branch: branch,
        editor: editor
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::BumpVersionUpdateChangelogCreatePRAction.available_options.size).to eq(11)
    end

    # TODO: Add more tests for the options
  end
end
