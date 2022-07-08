describe Fastlane::Actions::CreateNextSnapshotVersionAction do
  describe '#run' do
    let(:github_pr_token) { 'fake-github-pr-token' }
    let(:repo_name) { 'fake-repo-name' }
    let(:branch) { 'branch' }
    let(:current_version) { '1.12.0' }
    let(:next_version) { '1.13.0-SNAPSHOT' }

    it 'calls all the appropriate methods with appropriate parameters' do
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with(branch, github_pr_token)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:calculate_next_snapshot_version)
        .with(current_version)
        .and_return(next_version)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_and_checkout_new_branch)
        .with('bump/1.13.0-SNAPSHOT')
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, next_version, ['./test_file.sh', './test_file2.rb'], ['./test_file4.swift', './test_file5.kt'])
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commmit_changes_and_push_current_branch)
        .with('Preparing for next version')
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr_to_main)
        .with('Prepare next version: 1.13.0-SNAPSHOT', nil, repo_name, github_pr_token)
        .once
      Fastlane::Actions::CreateNextSnapshotVersionAction.run(
        current_version: current_version,
        repo_name: repo_name,
        github_pr_token: github_pr_token,
        files_to_update: ['./test_file.sh', './test_file2.rb'],
        files_to_update_without_prerelease_modifiers: ['./test_file4.swift', './test_file5.kt'],
        branch: branch
      )
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::CreateNextSnapshotVersionAction.available_options.size).to eq(6)
    end
  end
end
