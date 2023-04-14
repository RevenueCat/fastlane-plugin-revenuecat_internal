describe Fastlane::Actions::BumpPhcVersionAction do
  describe '#run' do
    let(:mock_github_pr_token) { 'mock-github-pr-token' }
    let(:mock_github_token) { 'mock-github-token' }
    let(:mock_repo_name) { 'mock-repo-name' }
    let(:editor) { 'vim' }
    let(:auto_generated_changelog) { 'mock-auto-generated-changelog' }
    let(:edited_changelog) { 'mock-edited-changelog' }
    let(:current_version) { '1.12.0' }
    let(:base_branch) { 'main' }
    let(:new_version) { '1.13.0' }
    let(:new_branch_name) { 'bump-phc/1.13.0' }
    let(:labels) { ['phc_dependencies', 'minor'] }

    it 'fails if version is invalid' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return('')

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with('Version number cannot be empty')
        .once
        .and_throw(:expected_error)

      catch :expected_error do
        Fastlane::Actions::BumpPhcVersionAction.run(
          current_version: current_version,
          repo_name: mock_repo_name,
          github_pr_token: mock_github_pr_token,
          github_token: mock_github_token
        )
      end
    end

    it 'calls all the appropriate methods with appropriate parameters' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with(new_branch_name, mock_github_pr_token)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, new_version, { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] }, {})
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
        .with("Version bump for #{new_version}")
        .once
      message = "Updates purchases-hybrid-common to 1.13.0"
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with(message, message, mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)
        .once

      Fastlane::Actions::BumpPhcVersionAction.run(
        current_version: current_version,
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        files_to_update: { './test_file.sh' => ['{x}'], './test_file2.rb' => ['{x}'] },
        open_pr: true
      )
    end

    it 'fails if selected no during prompt validating current branch' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(false)
      expect do
        Fastlane::Actions::BumpPhcVersionAction.run(
          current_version: current_version,
          repo_name: mock_repo_name,
          github_pr_token: mock_github_pr_token,
          github_token: mock_github_token,
          files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
          open_pr: true,
          next_version: new_version
        )
      end.to raise_exception(StandardError)
    end

    it 'does not prompt for branch confirmation if UI is not interactive' do
      setup_stubs

      Fastlane::Actions::BumpPhcVersionAction.run(
        current_version: current_version,
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        open_pr: true,
        next_version: new_version
      )
    end

    it 'adds automatic label to title and body' do
      setup_stubs

      message = "Updates purchases-hybrid-common to 1.13.0"
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with("[AUTOMATIC BUMP] #{message}", "**This is an automatic bump.**\n\n#{message}", mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)

      Fastlane::Actions::BumpPhcVersionAction.run(
        current_version: current_version,
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        open_pr: true,
        next_version: new_version,
        automatic_release: true
      )
    end

    it 'does not open PR if not required' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .never
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .never
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
        .never
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .never

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, new_version, { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] }, {})
        .once

      Fastlane::Actions::BumpPhcVersionAction.run(
        current_version: current_version,
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        open_pr: false
      )
    end

    it 'does not ask for version if it is passed to the function' do
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      expect(FastlaneCore::UI).to receive(:input)
        .never
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with(new_branch_name, mock_github_pr_token)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, new_version, { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] }, {})
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
        .with("Version bump for #{new_version}")
        .once
      message = "Updates purchases-hybrid-common to #{new_version}"
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with(message, message, mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)
        .once

      Fastlane::Actions::BumpPhcVersionAction.run(
        current_version: current_version,
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        open_pr: true,
        next_version: new_version
      )
    end

    it 'does not add the minor label if bump is not minor' do
      new_patch_version = '1.12.1'
      new_branch_name = 'bump-phc/1.12.1'
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      expect(FastlaneCore::UI).to receive(:input)
        .never
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with(new_branch_name, mock_github_pr_token)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, new_patch_version, { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] }, {})
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
        .with("Version bump for #{new_patch_version}")
        .once
      message = "Updates purchases-hybrid-common to 1.12.1"
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with(message, message, mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, ['phc_dependencies'])
        .once

      Fastlane::Actions::BumpPhcVersionAction.run(
        current_version: current_version,
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        open_pr: true,
        next_version: new_patch_version
      )
    end

    def setup_stubs
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(false)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(false)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with('bump-phc/1.13.0', mock_github_pr_token)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version, new_version, { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] }, {})
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
        .with("Version bump for #{new_version}")
      message = "Updates purchases-hybrid-common to 1.13.0"
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with(message, message, mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::BumpPhcVersionAction.available_options.size).to eq(7)
    end
  end
end
