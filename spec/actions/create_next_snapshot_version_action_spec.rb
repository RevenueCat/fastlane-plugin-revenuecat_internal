describe Fastlane::Actions::CreateNextSnapshotVersionAction do
  describe '#run' do
    let(:github_pr_token) { 'fake-github-pr-token' }
    let(:repo_name) { 'fake-repo-name' }
    let(:current_version) { '1.12.0' }
    let(:current_version_snapshot) { '1.12.0-SNAPSHOT' }
    let(:base_branch) { 'main' }
    let(:next_version) { '1.13.0-SNAPSHOT' }
    let(:new_branch_name) { 'bump/1.13.0-SNAPSHOT' }
    let(:labels) { ['next_release'] }

    it 'calls all the appropriate methods with appropriate parameters' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with("bump/#{next_version}", github_pr_token)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:calculate_next_snapshot_version)
        .with(current_version)
        .and_return(next_version)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version,
              next_version,
              { './test_file.sh' => ['{x}'], './test_file2.rb' => ['{x}'] },
              { './test_file4.swift' => ['{x}'], './test_file5.kt' => ['{x}'] })
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
        .with('Preparing for next version')
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with('Prepare next version: 1.13.0-SNAPSHOT', nil, repo_name, base_branch, new_branch_name, github_pr_token, labels)
        .once
      Fastlane::Actions::CreateNextSnapshotVersionAction.run(
        current_version: current_version,
        repo_name: repo_name,
        github_pr_token: github_pr_token,
        files_to_update: { './test_file.sh' => ['{x}'], './test_file2.rb' => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { './test_file4.swift' => ['{x}'], './test_file5.kt' => ['{x}'] }
      )
    end

    it 'skips if current version is SNAPSHOT' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:validate_local_config_status_for_bump)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:calculate_next_snapshot_version)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_new_branch_and_checkout)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:replace_version_number)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:commit_changes_and_push_current_branch)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_pr)
      Fastlane::Actions::CreateNextSnapshotVersionAction.run(
        current_version: current_version_snapshot,
        repo_name: repo_name,
        github_pr_token: github_pr_token,
        files_to_update: { './test_file.sh' => ['{x}'], './test_file2.rb' => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { './test_file4.swift' => ['{x}'], './test_file5.kt' => ['{x}'] }
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CreateNextSnapshotVersionAction.available_options.size).to eq(5)
    end
  end
end
