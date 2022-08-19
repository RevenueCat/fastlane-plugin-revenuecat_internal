describe Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction do
  describe '#run' do
    let(:mock_github_pr_token) { 'mock-github-pr-token' }
    let(:mock_github_token) { 'mock-github-token' }
    let(:mock_repo_name) { 'mock-repo-name' }
    let(:mock_changelog_latest_path) { './fake-changelog-latest-path/CHANGELOG.latest.md' }
    let(:mock_changelog_path) { './fake-changelog-path/CHANGELOG.md' }
    let(:editor) { 'vim' }
    let(:auto_generated_changelog) { 'mock-auto-generated-changelog' }
    let(:edited_changelog) { 'mock-edited-changelog' }
    let(:current_version) { '1.12.0' }
    let(:new_version) { '1.13.0' }
    let(:new_branch_name) { 'release/1.13.0' }
    let(:labels) { ['next_release'] }

    it 'fails if version is invalid' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return('')

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with('Version number cannot be empty')
        .once
        .and_throw(:expected_error)

      catch :expected_error do
        Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
          current_version: current_version,
          changelog_latest_path: mock_changelog_latest_path,
          changelog_path: mock_changelog_path,
          repo_name: mock_repo_name,
          github_pr_token: mock_github_pr_token,
          github_token: mock_github_token,
          editor: editor
        )
      end
    end

    it 'calls all the appropriate methods with appropriate parameters' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with('release/1.13.0', mock_github_pr_token)
        .once
      expect(Fastlane::Helper::VersioningHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3)
        .and_return(auto_generated_changelog)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:edit_changelog)
        .with(auto_generated_changelog, mock_changelog_latest_path, editor)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, new_version, ['./test_file.sh', './test_file2.rb'], ['./test_file3.kt', './test_file4.swift'])
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master)
        .with(new_version, mock_changelog_latest_path, mock_changelog_path)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commmit_changes_and_push_current_branch)
        .with("Version bump for #{new_version}")
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr_to_main)
        .with("Release/1.13.0", edited_changelog, mock_repo_name, new_branch_name, mock_github_pr_token, labels)
        .once

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift'],
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor
      )
    end

    it 'fails if selected no during prompt validating current branch' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(false)
      expect do
        Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
          current_version: current_version,
          changelog_latest_path: mock_changelog_latest_path,
          changelog_path: mock_changelog_path,
          files_to_update: ['./test_file.sh', './test_file2.rb'],
          files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift'],
          repo_name: mock_repo_name,
          github_pr_token: mock_github_pr_token,
          github_token: mock_github_token,
          github_rate_limit: 3,
          editor: editor
        )
      end.to raise_exception(StandardError)
    end

    it 'does not prompt for branch confirmation if UI is not interactive' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(false)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(false)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with('release/1.13.0', mock_github_pr_token)
      allow(Fastlane::Helper::VersioningHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3)
        .and_return(auto_generated_changelog)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, new_version, ['./test_file.sh', './test_file2.rb'], ['./test_file3.kt', './test_file4.swift'])
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master)
        .with(new_version, mock_changelog_latest_path, mock_changelog_path)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commmit_changes_and_push_current_branch)
        .with("Version bump for #{new_version}")
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr_to_main)
        .with("Release/1.13.0", edited_changelog, mock_repo_name, new_branch_name, mock_github_pr_token, labels)

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift'],
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor
      )
    end

    it 'does not edit changelog if UI is not interactive' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(false)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(false)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with('release/1.13.0', mock_github_pr_token)
      allow(Fastlane::Helper::VersioningHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3)
        .and_return(auto_generated_changelog)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, new_version, ['./test_file.sh', './test_file2.rb'], ['./test_file3.kt', './test_file4.swift'])
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master)
        .with(new_version, mock_changelog_latest_path, mock_changelog_path)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commmit_changes_and_push_current_branch)
        .with("Version bump for #{new_version}")
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr_to_main)
        .with("Release/1.13.0", edited_changelog, mock_repo_name, new_branch_name, mock_github_pr_token, labels)

      expect(Fastlane::Helper::RevenuecatInternalHelper).to_not(receive(:edit_changelog)
                                                                  .with(auto_generated_changelog, mock_changelog_latest_path, editor))
      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file3.kt', './test_file4.swift'],
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.available_options.size).to eq(11)
    end
  end
end
