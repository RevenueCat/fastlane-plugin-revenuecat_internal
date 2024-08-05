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
    let(:base_branch) { 'main' }
    let(:new_version) { '1.13.0' }
    let(:new_branch_name) { 'release/1.13.0' }
    let(:labels) { ['next_release'] }
    let(:hybrid_common_version) { '4.5.3' }
    let(:versions_file_path) { '../VERSIONS.md' }

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
      allow(Fastlane::Actions).to receive(:git_branch).and_return(base_branch)
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with('release/1.13.0', mock_github_pr_token)
        .once
      expect(Fastlane::Helper::VersioningHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3, false, nil, nil)
        .and_return(auto_generated_changelog)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:edit_changelog)
        .with(auto_generated_changelog, mock_changelog_latest_path, editor)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version,
              new_version,
              { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
              { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
              { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] })
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master)
        .with(new_version, mock_changelog_latest_path, mock_changelog_path)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
        .with("Version bump for #{new_version}")
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with("Release/1.13.0", edited_changelog, mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)
        .once

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
        files_to_update_on_latest_stable_releases: { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] },
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor,
        is_prerelease: false
      )
    end

    it 'generates changelog with appropriate parameters when bumping a hybrid SDK' do
      setup_stubs
      expect(Fastlane::Helper::VersioningHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3, false, hybrid_common_version, versions_file_path)
        .and_return(auto_generated_changelog)
        .once

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
        files_to_update_on_latest_stable_releases: { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] },
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor,
        hybrid_common_version: hybrid_common_version,
        versions_file_path: versions_file_path,
        is_prerelease: false
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
          files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
          files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
          files_to_update_on_latest_stable_releases: { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] },
          repo_name: mock_repo_name,
          github_pr_token: mock_github_pr_token,
          github_token: mock_github_token,
          github_rate_limit: 3,
          editor: editor,
          is_prerelease: false
        )
      end.to raise_exception(StandardError)
    end

    it 'does not prompt for branch confirmation if UI is not interactive' do
      setup_stubs

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
        files_to_update_on_latest_stable_releases: { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] },
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor,
        is_prerelease: false
      )
    end

    it 'does not edit changelog if UI is not interactive' do
      setup_stubs

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:write_changelog)
        .with(auto_generated_changelog, mock_changelog_latest_path)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to_not(receive(:edit_changelog)
                                                                  .with(auto_generated_changelog, mock_changelog_latest_path, editor))
      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
        files_to_update_on_latest_stable_releases: { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] },
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor,
        is_prerelease: false
      )
    end

    it 'adds automatic label to title and body' do
      setup_stubs

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with("[AUTOMATIC] Release/1.13.0", "**This is an automatic release.**\n\nmock-edited-changelog", mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
        files_to_update_on_latest_stable_releases: { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] },
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor,
        automatic_release: true,
        is_prerelease: false
      )
    end

    it 'fails trying to append PHC version if is_prerelease is true' do
      new_version_provided = new_version
      is_prerelease = true

      test_fails_to_append_phc_version_if_new_version_is_prerelease(is_prerelease, new_version_provided)
    end

    it 'fails trying to append PHC version if new version is prerelease' do
      new_version_provided = '1.13.0-alpha.1'
      is_prerelease = false

      test_fails_to_append_phc_version_if_new_version_is_prerelease(is_prerelease, new_version_provided)
    end

    it 'fails trying to append a nil PHC version' do
      hybrid_common_version_provided = nil
      expected_error = "Cannot append a nil PHC version."

      test_fails_to_append_incorrect_phc_version(hybrid_common_version_provided, expected_error)
    end

    it 'fails trying to append a blank PHC version' do
      hybrid_common_version_provided = " "
      expected_error = "Cannot append a blank PHC version."

      test_fails_to_append_incorrect_phc_version(hybrid_common_version_provided, expected_error)
    end

    it 'fails if append_phc_version_if_next_version_is_not_prerelease is true and provided version metadata does not match - interactive' do
      interactive = true
      append_phc_version_if_next_version_is_not_prerelease = true
      mismatched_metadata = "some.metadata"

      test_fails_appending_phc_version(
        interactive,
        append_phc_version_if_next_version_is_not_prerelease,
        mismatched_metadata
      )
    end

    it 'fails if append_phc_version_if_next_version_is_not_prerelease is true and provided version has + but no metadata - interactive' do
      interactive = true
      append_phc_version_if_next_version_is_not_prerelease = true
      mismatched_metadata = "" # Empty on purpose

      test_fails_appending_phc_version(
        interactive,
        append_phc_version_if_next_version_is_not_prerelease,
        mismatched_metadata
      )
    end

    it 'fails if append_phc_version_if_next_version_is_not_prerelease is true and provided version metadata does not match - non-interactive' do
      interactive = false
      append_phc_version_if_next_version_is_not_prerelease = true
      mismatched_metadata = "some.metadata"

      test_fails_appending_phc_version(
        interactive,
        append_phc_version_if_next_version_is_not_prerelease,
        mismatched_metadata
      )
    end

    it 'fails if append_phc_version_if_next_version_is_not_prerelease is true and provided version has + but no metadata - non-interactive' do
      interactive = false
      append_phc_version_if_next_version_is_not_prerelease = true
      mismatched_metadata = "" # Empty on purpose

      test_fails_appending_phc_version(
        interactive,
        append_phc_version_if_next_version_is_not_prerelease, mismatched_metadata
      )
    end

    it 'appends the PHC version automatically if append_phc_version_if_next_version_is_not_prerelease is true and provided version lacks metadata - interactive' do
      interactive = true
      append_phc_version_if_next_version_is_not_prerelease = true
      expected_version = "#{new_version}+#{hybrid_common_version}"
      # We are providing new_version, without PHC appended as metadata
      new_version_provided = new_version

      test_actual_version(
        interactive,
        false,
        new_version_provided,
        append_phc_version_if_next_version_is_not_prerelease,
        expected_version
      )
    end

    it 'succeeds if append_phc_version_if_next_version_is_not_prerelease is true and provided version metadata matches - interactive' do
      interactive = true
      append_phc_version_if_next_version_is_not_prerelease = true
      expected_version = "#{new_version}+#{hybrid_common_version}"
      # We are providing expected_version, with the correct PHC version already appended as metadata
      new_version_provided = expected_version

      test_actual_version(
        interactive,
        false,
        new_version_provided,
        append_phc_version_if_next_version_is_not_prerelease,
        expected_version
      )
    end

    it 'appends the PHC version automatically if append_phc_version_if_next_version_is_not_prerelease is true and provided version lacks metadata - non-interactive' do
      interactive = false
      append_phc_version_if_next_version_is_not_prerelease = true
      expected_version = "#{new_version}+#{hybrid_common_version}"
      # We are providing new_version, without PHC appended as metadata
      new_version_provided = new_version

      test_actual_version(
        interactive,
        false,
        new_version_provided,
        append_phc_version_if_next_version_is_not_prerelease,
        expected_version
      )
    end

    it 'succeeds if append_phc_version_if_next_version_is_not_prerelease is true and provided version metadata matches - non-interactive' do
      interactive = false
      append_phc_version_if_next_version_is_not_prerelease = true
      expected_version = "#{new_version}+#{hybrid_common_version}"
      # We are providing expected_version, with the correct PHC version already appended as metadata
      new_version_provided = expected_version

      test_actual_version(
        interactive,
        false,
        new_version_provided,
        append_phc_version_if_next_version_is_not_prerelease,
        expected_version
      )
    end

    it 'does not add phc version if next version is pre-release - interactive' do
      interactive = true
      append_phc_version_if_next_version_is_not_prerelease = true
      expected_version = "1.2.3-alpha.1"
      # We are providing expected_version, which is pre-release
      new_version_provided = expected_version

      test_actual_version(
        interactive,
        false,
        new_version_provided,
        append_phc_version_if_next_version_is_not_prerelease,
        expected_version
      )
    end

    it 'does not add phc version if next version is pre-release - non-interactive' do
      interactive = false
      append_phc_version_if_next_version_is_not_prerelease = true
      expected_version = "1.2.3-alpha.1"
      # We are providing expected_version, which is pre-release
      new_version_provided = expected_version

      test_actual_version(
        interactive,
        false,
        new_version_provided,
        append_phc_version_if_next_version_is_not_prerelease,
        expected_version
      )
    end

    it 'does not add phc version if is_prerelease is true - interactive' do
      interactive = true
      append_phc_version_if_next_version_is_not_prerelease = true
      expected_version = "1.2.3"
      # We are providing expected_version, which is not pre-release
      new_version_provided = expected_version

      test_actual_version(
        interactive,
        true,
        new_version_provided,
        append_phc_version_if_next_version_is_not_prerelease,
        expected_version
      )
    end

    it 'does not add phc version if is_prerelease is true - interactive' do
      interactive = false
      append_phc_version_if_next_version_is_not_prerelease = true
      expected_version = "1.2.3"
      # We are providing expected_version, which is not pre-release
      new_version_provided = expected_version

      test_actual_version(
        interactive,
        true,
        new_version_provided,
        append_phc_version_if_next_version_is_not_prerelease,
        expected_version
      )
    end

    it 'asks to append a PHC version if all conditions are met' do
      new_version_appended = "#{new_version}+#{hybrid_common_version}"
      new_branch_name = "release/#{new_version_appended}"
      allow(Fastlane::Actions).to receive(:git_branch).and_return(base_branch)
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)
      allow(Fastlane::Helper::VersioningHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3, false, hybrid_common_version, nil)
        .and_return(auto_generated_changelog)
        .once
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:edit_changelog)
        .with(auto_generated_changelog, mock_changelog_latest_path, editor)
        .once

      expect(FastlaneCore::UI).to receive(:confirm)
        .with("Would you like to append the PHC version (+#{hybrid_common_version})?")
        .once
        .and_return(true)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with(new_branch_name, mock_github_pr_token)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version,
              new_version_appended,
              { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
              { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
              { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] })
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master)
        .with(new_version_appended, mock_changelog_latest_path, mock_changelog_path)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with("Release/#{new_version_appended}", edited_changelog, mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)
        .once

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
        files_to_update_on_latest_stable_releases: { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] },
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor,
        hybrid_common_version: hybrid_common_version,
        is_prerelease: false,
        append_phc_version_if_next_version_is_not_prerelease: nil
      )
    end

    it 'does not ask to append a PHC version if hybrid_common_version is nil' do
      test_does_not_ask_to_append_phc_version(nil)
    end

    it 'does not ask to append a PHC version if hybrid_common_version is blank' do
      test_does_not_ask_to_append_phc_version(" ")
    end

    def test_fails_to_append_incorrect_phc_version(hybrid_common_version_provided, expected_error)
      allow(Fastlane::Actions).to receive(:git_branch).and_return(base_branch)
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with(expected_error)
        .once
        .and_throw(:expected_error)

      catch(:expected_error) do
        Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
          current_version: current_version,
          changelog_latest_path: mock_changelog_latest_path,
          changelog_path: mock_changelog_path,
          repo_name: mock_repo_name,
          github_pr_token: mock_github_pr_token,
          github_token: mock_github_token,
          editor: editor,
          hybrid_common_version: hybrid_common_version_provided,
          is_prerelease: false,
          append_phc_version_if_next_version_is_not_prerelease: true
        )
      end
    end

    def test_fails_to_append_phc_version_if_new_version_is_prerelease(is_prerelease, new_version_provided)
      allow(Fastlane::Actions).to receive(:git_branch).and_return(base_branch)
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version_provided)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with('Appending the PHC version to prerelease versions violates SemVer.')
        .once
        .and_throw(:expected_error)

      catch(:expected_error) do
        Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
          current_version: current_version,
          changelog_latest_path: mock_changelog_latest_path,
          changelog_path: mock_changelog_path,
          repo_name: mock_repo_name,
          github_pr_token: mock_github_pr_token,
          github_token: mock_github_token,
          editor: editor,
          hybrid_common_version: hybrid_common_version,
          is_prerelease: is_prerelease,
          append_phc_version_if_next_version_is_not_prerelease: true
        )
      end
    end

    def test_does_not_ask_to_append_phc_version(hybrid_common_version)
      allow(Fastlane::Actions).to receive(:git_branch).and_return(base_branch)
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(true)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)
      allow(Fastlane::Helper::VersioningHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3, false, hybrid_common_version, nil)
        .and_return(auto_generated_changelog)
        .once
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:edit_changelog)
        .with(auto_generated_changelog, mock_changelog_latest_path, editor)
        .once
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with(new_branch_name, mock_github_pr_token)
        .once
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version,
              new_version,
              { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
              { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
              { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] })
        .once
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master)
        .with(new_version, mock_changelog_latest_path, mock_changelog_path)
        .once
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with("Release/#{new_version}", edited_changelog, mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)
        .once

      expect(FastlaneCore::UI).not_to receive(:confirm)
        .with("Would you like to append the PHC version (+#{hybrid_common_version})?")

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
        files_to_update_on_latest_stable_releases: { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] },
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor,
        hybrid_common_version: hybrid_common_version,
        is_prerelease: false,
        append_phc_version_if_next_version_is_not_prerelease: nil
      )
    end

    def test_actual_version(interactive, is_prerelease, new_version_provided, append_phc_version_if_next_version_is_not_prerelease, expected_version)
      new_branch_name = "release/#{expected_version}"
      allow(Fastlane::Actions).to receive(:git_branch).and_return(base_branch)
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(interactive)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version_provided) if interactive
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)
      allow(Fastlane::Helper::VersioningHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3, false, hybrid_common_version, nil)
        .and_return(auto_generated_changelog)
        .once
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:write_changelog)
        .with(auto_generated_changelog, mock_changelog_latest_path)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:edit_changelog)
        .with(auto_generated_changelog, mock_changelog_latest_path, editor)
        .once

      expect(FastlaneCore::UI).not_to receive(:confirm)
        .with("Would you like to append the PHC version (+#{hybrid_common_version})?")
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with(new_branch_name, mock_github_pr_token)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version,
              expected_version,
              { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
              { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
              { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] })
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master)
        .with(expected_version, mock_changelog_latest_path, mock_changelog_path)
        .once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with("Release/#{expected_version}", edited_changelog, mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)
        .once

      Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
        current_version: current_version,
        next_version: interactive ? nil : new_version_provided,
        changelog_latest_path: mock_changelog_latest_path,
        changelog_path: mock_changelog_path,
        files_to_update: { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
        files_to_update_without_prerelease_modifiers: { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
        files_to_update_on_latest_stable_releases: { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] },
        repo_name: mock_repo_name,
        github_pr_token: mock_github_pr_token,
        github_token: mock_github_token,
        github_rate_limit: 3,
        editor: editor,
        hybrid_common_version: hybrid_common_version,
        is_prerelease: is_prerelease,
        append_phc_version_if_next_version_is_not_prerelease: append_phc_version_if_next_version_is_not_prerelease
      )
    end

    def test_fails_appending_phc_version(interactive, append_phc_version_if_next_version_is_not_prerelease, mismatched_metadata)
      allow(Fastlane::Actions).to receive(:git_branch).and_return(base_branch)
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(interactive)
      # We are providing a version with metadata that doesn't match the PHC version
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return("#{new_version}+#{mismatched_metadata}")
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(true)

      expect(FastlaneCore::UI).not_to receive(:confirm)
        .with("Would you like to append the PHC version (+#{hybrid_common_version})?")
      expect(FastlaneCore::UI).to receive(:user_error!)
        .with("Asked to append PHC version (+#{hybrid_common_version}), but the provided version (#{new_version}+#{mismatched_metadata}) already has metadata (+#{mismatched_metadata}).")
        .once
        .and_throw(:expected_error)

      catch(:expected_error) do
        Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.run(
          current_version: current_version,
          changelog_latest_path: mock_changelog_latest_path,
          changelog_path: mock_changelog_path,
          repo_name: mock_repo_name,
          github_pr_token: mock_github_pr_token,
          github_token: mock_github_token,
          github_rate_limit: 3,
          editor: editor,
          hybrid_common_version: hybrid_common_version,
          is_prerelease: false,
          append_phc_version_if_next_version_is_not_prerelease: append_phc_version_if_next_version_is_not_prerelease
        )
      end
    end

    def setup_stubs
      allow(Fastlane::Actions).to receive(:git_branch).and_return(base_branch)
      allow(FastlaneCore::UI).to receive(:interactive?).and_return(false)
      allow(FastlaneCore::UI).to receive(:input).with('New version number: ').and_return(new_version)
      allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(false)
      allow(File).to receive(:read).with(mock_changelog_latest_path).and_return(edited_changelog)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:validate_local_config_status_for_bump)
        .with('release/1.13.0', mock_github_pr_token)
      allow(Fastlane::Helper::VersioningHelper).to receive(:auto_generate_changelog)
        .with(mock_repo_name, mock_github_token, 3, false, nil, nil)
        .and_return(auto_generated_changelog)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:write_changelog)
        .with(auto_generated_changelog, mock_changelog_latest_path)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(new_branch_name)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
        .with(current_version,
              new_version,
              { "./test_file.sh" => ['{x}'], "./test_file2.rb" => ['{x}'] },
              { "./test_file3.kt" => ['{x}'], "./test_file4.swift" => ['{x}'] },
              { "./test_file5.kt" => ['{x}'], "./test_file6.swift" => ['{x}'] })
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_master)
        .with(new_version, mock_changelog_latest_path, mock_changelog_path)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
        .with("Version bump for #{new_version}")
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with("Release/1.13.0", edited_changelog, mock_repo_name, base_branch, new_branch_name, mock_github_pr_token, labels)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::BumpVersionUpdateChangelogCreatePrAction.available_options.size).to eq(17)
    end
  end
end
