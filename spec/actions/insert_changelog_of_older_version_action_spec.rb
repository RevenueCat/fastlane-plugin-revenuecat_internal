describe Fastlane::Actions::InsertChangelogOfOlderVersionAction do
  describe '#run' do
    let(:sdk_version) { '1.10.0' }
    let(:changelog_path) { './fake-changelog-path/CHANGELOG.md' }
    let(:changelog_latest_path) { './fake-changelog-latest-path/CHANGELOG.latest.md' }
    let(:repo_name) { 'mock-repo-name' }
    let(:base_branch) { 'main' }
    let(:github_pr_token) { 'mock-github-token' }
    let(:current_branch) { 'release/1.10.0' }
    let(:changelog_update_branch_name) { "changelog/#{sdk_version}" }
    let(:changelog_content) { "## 1.10.0\n* Bug fixes\n* Performance improvements" }

    it 'skips changelog insertion when version is not older than latest published version' do
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:older_than_latest_published_version?)
        .with(sdk_version)
        .and_return(false)

      expect(FastlaneCore::UI).to receive(:message)
        .with("Version #{sdk_version} is not older than the latest published version. Skipping changelog insertion.")
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_or_checkout_branch)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_new_branch_and_checkout)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:insert_old_version_changelog_in_current_branch)

      Fastlane::Actions::InsertChangelogOfOlderVersionAction.run(
        sdk_version: sdk_version,
        changelog_path: changelog_path,
        changelog_latest_path: changelog_latest_path,
        repo_name: repo_name,
        base_branch: base_branch,
        github_pr_token: github_pr_token
      )
    end

    it 'inserts changelog and creates PR when version is older than latest published version' do
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:older_than_latest_published_version?)
        .with(sdk_version)
        .and_return(true)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:is_git_repo_dirty).and_return(false)
      allow(Fastlane::Actions).to receive(:git_branch).and_return(current_branch)
      allow(File).to receive(:read).with(changelog_latest_path).and_return(changelog_content)

      expect(FastlaneCore::UI).to receive(:important)
        .with("Version #{sdk_version} is older than the latest published version. Proceeding with changelog insertion into #{base_branch}.")
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_or_checkout_branch)
        .with(base_branch)
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
        .with(changelog_update_branch_name)
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:insert_old_version_changelog_in_current_branch)
        .with(sdk_version, changelog_content, changelog_path)
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
        .with("Changelog update for #{sdk_version}")
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)
        .with("Changelog update for #{sdk_version}", changelog_content, repo_name, base_branch, changelog_update_branch_name, github_pr_token, labels: ["pr:other", "pr:changelog_ignore"])
        .once

      expect(FastlaneCore::UI).to receive(:success)
        .with("Successfully created PR for changelog update of version #{sdk_version}")
        .once

      Fastlane::Actions::InsertChangelogOfOlderVersionAction.run(
        sdk_version: sdk_version,
        changelog_path: changelog_path,
        changelog_latest_path: changelog_latest_path,
        repo_name: repo_name,
        base_branch: base_branch,
        github_pr_token: github_pr_token
      )
    end

    it 'performs dry run without creating branches or PR' do
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:older_than_latest_published_version?)
        .with(sdk_version)
        .and_return(true)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:is_git_repo_dirty).and_return(false)
      allow(Fastlane::Actions).to receive(:git_branch).and_return(current_branch)
      allow(File).to receive(:read).with(changelog_latest_path).and_return(changelog_content)

      git_diff_output = "+## 1.10.0\n+* Bug fixes\n+* Performance improvements"
      allow(Fastlane::Actions).to receive(:sh).with("git diff #{changelog_path}", log: false).and_return(git_diff_output)

      expect(FastlaneCore::UI).to receive(:important)
        .with("Version #{sdk_version} is older than the latest published version. Proceeding with changelog insertion into #{base_branch}.")
        .once

      expect(FastlaneCore::UI).to receive(:important)
        .with("Dry run mode enabled. No changes will be made.")
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_or_checkout_branch)
        .with(base_branch)
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_new_branch_and_checkout)

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:insert_old_version_changelog_in_current_branch)
        .with(sdk_version, changelog_content, changelog_path)
        .once

      expect(FastlaneCore::UI).to receive(:important)
        .with(/The changelog diff would be:/)
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:discard_changes_in_current_branch)
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_or_checkout_branch)
        .with(current_branch)
        .once

      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:commit_changes_and_push_current_branch)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_pr)

      Fastlane::Actions::InsertChangelogOfOlderVersionAction.run(
        sdk_version: sdk_version,
        changelog_path: changelog_path,
        changelog_latest_path: changelog_latest_path,
        repo_name: repo_name,
        base_branch: base_branch,
        github_pr_token: github_pr_token,
        dry_run: true
      )
    end

    it 'passes optional parameters correctly' do
      hybrid_common_version = '4.5.3'
      append_phc_version = true

      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:older_than_latest_published_version?)
        .with(sdk_version)
        .and_return(true)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:is_git_repo_dirty).and_return(false)
      allow(Fastlane::Actions).to receive(:git_branch).and_return(current_branch)
      allow(File).to receive(:read).with(changelog_latest_path).and_return(changelog_content)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_or_checkout_branch)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_new_branch_and_checkout)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:insert_old_version_changelog_in_current_branch)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_changes_and_push_current_branch)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr)

      Fastlane::Actions::InsertChangelogOfOlderVersionAction.run(
        sdk_version: sdk_version,
        changelog_path: changelog_path,
        changelog_latest_path: changelog_latest_path,
        repo_name: repo_name,
        base_branch: base_branch,
        github_pr_token: github_pr_token,
        hybrid_common_version: hybrid_common_version,
        append_phc_version: append_phc_version
      )
    end

    it 'aborts when git repo is dirty in non-dry_run mode' do
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:older_than_latest_published_version?)
        .with(sdk_version)
        .and_return(true)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:is_git_repo_dirty).and_return(true)
      allow(Fastlane::Actions).to receive(:git_branch).and_return(current_branch)
      allow(File).to receive(:read).with(changelog_latest_path).and_return(changelog_content)

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with("Your working directory has uncommitted changes. Please commit or stash them before running this action.")
        .and_raise(FastlaneCore::Interface::FastlaneError)

      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_or_checkout_branch)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_new_branch_and_checkout)

      expect do
        Fastlane::Actions::InsertChangelogOfOlderVersionAction.run(
          sdk_version: sdk_version,
          changelog_path: changelog_path,
          changelog_latest_path: changelog_latest_path,
          repo_name: repo_name,
          base_branch: base_branch,
          github_pr_token: github_pr_token
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError)
    end

    it 'aborts when git repo is dirty in dry_run mode' do
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:older_than_latest_published_version?)
        .with(sdk_version)
        .and_return(true)
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:is_git_repo_dirty).and_return(true)
      allow(Fastlane::Actions).to receive(:git_branch).and_return(current_branch)
      allow(File).to receive(:read).with(changelog_latest_path).and_return(changelog_content)

      expect(FastlaneCore::UI).to receive(:user_error!)
        .with("Your working directory has uncommitted changes. Please commit or stash them before running this action.")
        .and_raise(FastlaneCore::Interface::FastlaneError)

      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_or_checkout_branch)
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:insert_old_version_changelog_in_current_branch)

      expect do
        Fastlane::Actions::InsertChangelogOfOlderVersionAction.run(
          sdk_version: sdk_version,
          changelog_path: changelog_path,
          changelog_latest_path: changelog_latest_path,
          repo_name: repo_name,
          base_branch: base_branch,
          github_pr_token: github_pr_token,
          dry_run: true
        )
      end.to raise_error(FastlaneCore::Interface::FastlaneError)
    end
  end

  describe '#available_options' do
    it 'has correct number of options' do
      expect(Fastlane::Actions::InsertChangelogOfOlderVersionAction.available_options.size).to eq(9)
    end
  end

  describe '#description' do
    it 'returns correct description' do
      expect(Fastlane::Actions::InsertChangelogOfOlderVersionAction.description).to eq(
        "Inserts changelog content for an older version into the main CHANGELOG.md at the correct position"
      )
    end
  end

  describe '#is_supported?' do
    it 'supports all platforms' do
      expect(Fastlane::Actions::InsertChangelogOfOlderVersionAction.is_supported?(:ios)).to be true
      expect(Fastlane::Actions::InsertChangelogOfOlderVersionAction.is_supported?(:android)).to be true
      expect(Fastlane::Actions::InsertChangelogOfOlderVersionAction.is_supported?(:mac)).to be true
    end
  end
end
