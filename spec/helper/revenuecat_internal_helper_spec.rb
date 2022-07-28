describe Fastlane::Helper::RevenuecatInternalHelper do
  describe '.replace_version_number' do
    require 'fileutils'

    let(:file_to_update_1) { './tmp_test_files/file_to_update_1.txt' }
    let(:file_to_update_2) { './tmp_test_files/file_to_update_2.txt' }
    let(:file_to_update_without_prerelease_modifiers_3) { './tmp_test_files/file_to_update_3.txt' }
    let(:file_to_update_without_prerelease_modifiers_4) { './tmp_test_files/file_to_update_4.txt' }

    before(:each) do
      Dir.mkdir('./tmp_test_files')
    end

    after(:each) do
      FileUtils.rm_rf('./tmp_test_files')
    end

    it 'updates previous version number with new version number when no prerelease modifiers are passed' do
      File.write(file_to_update_1, 'Contains version: 1.11.0')
      File.write(file_to_update_2, 'Contains version: 1.11.0 and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0')

      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0',
        '1.12.0',
        [file_to_update_1, file_to_update_2],
        [file_to_update_without_prerelease_modifiers_3, file_to_update_without_prerelease_modifiers_4]
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0 and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0')
    end

    it 'updates previous version number with new version number when current version has prerelease modifiers' do
      File.write(file_to_update_1, 'Contains version: 1.11.0 and version with snapshot: 1.11.0-SNAPSHOT')
      File.write(file_to_update_2, 'Contains version: 1.11.0-SNAPSHOT and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0')

      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0-SNAPSHOT',
        '1.12.0',
        [file_to_update_1, file_to_update_2],
        [file_to_update_without_prerelease_modifiers_3, file_to_update_without_prerelease_modifiers_4]
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.11.0 and version with snapshot: 1.12.0')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0 and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0')
    end

    it 'updates previous version number with new version number when new version has prerelease modifiers' do
      File.write(file_to_update_1, 'Contains version: 1.11.0')
      File.write(file_to_update_2, 'Contains version: 1.11.0 and other version: 1.11.1')
      File.write(file_to_update_without_prerelease_modifiers_3, 'Contains version: 1.11.0')
      File.write(file_to_update_without_prerelease_modifiers_4, 'Contains version: 1.11.0')

      Fastlane::Helper::RevenuecatInternalHelper.replace_version_number(
        '1.11.0',
        '1.12.0-SNAPSHOT',
        [file_to_update_1, file_to_update_2],
        [file_to_update_without_prerelease_modifiers_3, file_to_update_without_prerelease_modifiers_4]
      )

      expect(File.read(file_to_update_1)).to eq('Contains version: 1.12.0-SNAPSHOT')
      expect(File.read(file_to_update_2)).to eq('Contains version: 1.12.0-SNAPSHOT and other version: 1.11.1')
      expect(File.read(file_to_update_without_prerelease_modifiers_3)).to eq('Contains version: 1.12.0')
      expect(File.read(file_to_update_without_prerelease_modifiers_4)).to eq('Contains version: 1.12.0')
    end
  end

  describe '.auto_generate_changelog' do
    let(:server_url) { 'https://api.github.com' }
    let(:http_method) { 'GET' }
    let(:get_commits_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commits_since_last_release.json") }
    end
    let(:get_commit_1_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_a72c0435ecf71248f311900475e881cc07ac2eaf.json") }
    end
    let(:get_commit_2_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_0e67cdb1c7582ce3e2fd00367acc24db6242c6d6.json") }
    end
    let(:get_commit_3_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_cfdd80f73d8c91121313d72227b4cbe283b57c1e.json") }
    end
    let(:duplicate_items_get_commit_2_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/duplicate_items_get_commit_sha_0e67cdb1c7582ce3e2fd00367acc24db6242c6d6.json") }
    end

    it 'generates changelog automatically from github commits' do
      setup_stubs
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::RevenuecatInternalHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0
      )
      expect(changelog).to eq("* Prepare next version: 4.8.0-SNAPSHOT (#1750) via RevenueCat Releases (@revenuecat-ops)\n" \
                              "* Fix replace version without prerelease modifiers (#1751) via Toni Rico (@tonidero)\n" \
                              "* added a log when `autoSyncPurchases` is disabled (#1749) via aboedo (@aboedo)")
    end

    it 'sleeps between getting commits info if passing rate limit sleep' do
      setup_stubs
      expect_any_instance_of(Object).to receive(:sleep).with(3).exactly(3).times
      changelog = Fastlane::Helper::RevenuecatInternalHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        3
      )
      expect(changelog).to eq("* Prepare next version: 4.8.0-SNAPSHOT (#1750) via RevenueCat Releases (@revenuecat-ops)\n" \
                              "* Fix replace version without prerelease modifiers (#1751) via Toni Rico (@tonidero)\n" \
                              "* added a log when `autoSyncPurchases` is disabled (#1749) via aboedo (@aboedo)")
    end

    it 'fails if it finds multiple commits with same sha' do
      setup_stubs
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:0e67cdb1c7582ce3e2fd00367acc24db6242c6d6',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(duplicate_items_get_commit_2_response)
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.auto_generate_changelog(
          'mock-repo-name',
          'mock-github-token',
          0
        )
      end.to raise_exception(StandardError)
    end

    def setup_stubs
      allow(Fastlane::Actions).to receive(:sh).with('git describe --tags --abbrev=0').and_return('1.11.0')
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/repos/RevenueCat/mock-repo-name/compare/1.11.0...HEAD',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(get_commits_response)
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:a72c0435ecf71248f311900475e881cc07ac2eaf',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(get_commit_1_response)
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:0e67cdb1c7582ce3e2fd00367acc24db6242c6d6',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(get_commit_2_response)
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:cfdd80f73d8c91121313d72227b4cbe283b57c1e',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(get_commit_3_response)
    end
  end

  describe '.edit_changelog' do
    let(:prepopulated_changelog) { 'mock prepopulated changelog' }
    let(:changelog_latest_path) { './mock-path/CHANGELOG.latest.md' }
    let(:editor) { 'vim' }

    before(:each) do
      allow(File).to receive(:read).with(changelog_latest_path).and_return('edited changelog')
      allow(File).to receive(:write).with(changelog_latest_path, prepopulated_changelog)
      allow(FastlaneCore::UI).to receive(:confirm).with('Open CHANGELOG.latest.md in \'vim\'? (No will quit this process)').and_return(true)
      allow_any_instance_of(Object).to receive(:system).with(editor, changelog_latest_path)
    end

    it 'writes prepopulated changelog to latest changelog file' do
      expect(File).to receive(:write).with(changelog_latest_path, prepopulated_changelog).once
      Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
    end

    it 'opens editor to edit prepopulated changelog' do
      expect_any_instance_of(Object).to receive(:system).with(editor, changelog_latest_path).once
      Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
    end

    it 'fails if prepopulated changelog is empty' do
      expect(File).not_to receive(:write)
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.edit_changelog('', changelog_latest_path, editor)
      end.to raise_exception(StandardError)
    end

    it 'fails if user cancels on confirmation to open editor' do
      expect(File).not_to receive(:write)
      allow(FastlaneCore::UI).to receive(:confirm).with('Open CHANGELOG.latest.md in \'vim\'? (No will quit this process)').and_return(false)
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
      end.to raise_exception(StandardError)
    end

    it 'asks for confirmation if prepopulated changelog remains the same after editor opening' do
      allow(File).to receive(:read).with(changelog_latest_path).and_return(prepopulated_changelog)
      expect(FastlaneCore::UI).to receive(:confirm)
        .with('You may have opened the changelog in a visual editor. Enter \'y\' when changes are saved or \'n\' to cancel').and_return(true).once
      Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
    end

    it 'fails if confirmation if prepopulated changelog remains the same after editor opening' do
      allow(File).to receive(:read).with(changelog_latest_path).and_return(prepopulated_changelog)
      expect(FastlaneCore::UI).to receive(:confirm)
        .with('You may have opened the changelog in a visual editor. Enter \'y\' when changes are saved or \'n\' to cancel').and_return(false).once
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
      end.to raise_exception(StandardError)
    end
  end

  describe '.attach_changelog_to_master' do
    require 'fileutils'

    let(:version_number) { '1.12.0' }
    let(:tmp_test_files_path) { './tmp_test_files' }
    let(:changelog_latest_path) { './tmp_test_files/CHANGELOG.latest.md' }
    let(:changelog_path) { './tmp_test_files/CHANGELOG.md' }

    before(:each) do
      Dir.mkdir(tmp_test_files_path)
      File.write(changelog_latest_path, 'changelog latest contents')
      File.write(changelog_path, "## 1.11.0\nchangelog contents")
    end

    after(:each) do
      FileUtils.rm_rf(tmp_test_files_path)
    end

    it 'prepends changelog latest file contents to changelog file' do
      Fastlane::Helper::RevenuecatInternalHelper.attach_changelog_to_master(version_number, changelog_latest_path, changelog_path)
      changelog_contents = File.read(changelog_path)
      expect(changelog_contents).to eq("## 1.12.0\nchangelog latest contents\n## 1.11.0\nchangelog contents")
    end
  end

  describe '.create_new_branch_and_checkout' do
    it 'creates new release branch with version number' do
      expect(Fastlane::Actions).to receive(:sh).with("git checkout -b 'fake-branch'")
      Fastlane::Helper::RevenuecatInternalHelper.create_new_branch_and_checkout('fake-branch')
    end
  end

  describe '.commmit_changes_and_push_current_branch' do
    before(:each) do
      allow(Fastlane::Actions).to receive(:sh).with(anything)
      allow(Fastlane::Actions::PushToGitRemoteAction).to receive(:run).with(remote: 'origin')
    end

    it 'stages files' do
      expect(Fastlane::Actions).to receive(:sh).with('git add -u').once
      Fastlane::Helper::RevenuecatInternalHelper.commmit_changes_and_push_current_branch('Fastlane test commit message')
    end

    it 'commits files with correct message' do
      expect(Fastlane::Actions).to receive(:sh).with("git commit -m 'Fastlane test commit message'").once
      Fastlane::Helper::RevenuecatInternalHelper.commmit_changes_and_push_current_branch('Fastlane test commit message')
    end

    it 'pushes to remote' do
      expect(Fastlane::Actions::PushToGitRemoteAction).to receive(:run).with(remote: 'origin').once
      Fastlane::Helper::RevenuecatInternalHelper.commmit_changes_and_push_current_branch('Fastlane test commit message')
    end
  end

  describe '.create_pr_to_main' do
    it 'creates pr' do
      allow(Fastlane::Actions).to receive(:git_branch).and_return('fake-current-branch')
      expect(Fastlane::Actions::CreatePullRequestAction).to receive(:run)
        .with(
          api_token: 'fake-github-pr-token',
          title: 'fake-title',
          base: 'main',
          body: 'fake-changelog',
          repo: 'RevenueCat/fake-repo-name',
          head: 'fake-current-branch',
          api_url: 'https://api.github.com'
        ).once
      Fastlane::Helper::RevenuecatInternalHelper.create_pr_to_main('fake-title', 'fake-changelog', 'fake-repo-name', 'fake-github-pr-token')
    end
  end

  describe '.validate_local_config_status_for_bump' do
    before(:each) do
      allow(Fastlane::Actions).to receive(:sh).with('git', 'branch', '--list', 'new-branch').and_return('')
      allow(Fastlane::Actions).to receive(:sh).with('git', 'ls-remote', '--heads', 'origin', 'new-branch').and_return('')
      allow(Fastlane::Actions::EnsureGitBranchAction).to receive(:run).with(branch: 'fake-branch')
      allow(Fastlane::Actions::EnsureGitStatusCleanAction).to receive(:run)
    end

    it 'fails if github_pr_token is nil' do
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('fake-branch', 'new-branch', nil)
      end.to raise_exception(StandardError)
    end

    it 'fails if github_pr_token is empty' do
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('fake-branch', 'new-branch', '')
      end.to raise_exception(StandardError)
    end

    it 'fails if new branch exists locally' do
      expect(Fastlane::Actions).to receive(:sh).with('git', 'branch', '--list', 'new-branch').and_return('new-branch').once
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('fake-branch', 'new-branch', 'fake-github-pr-token')
      end.to raise_exception(StandardError)
    end

    it 'fails if new branch exists remotely' do
      expect(Fastlane::Actions).to receive(:sh)
        .with('git', 'ls-remote', '--heads', 'origin', 'new-branch')
        .and_return('59f7273ae446cef04eb402b9708f0772389c59c4  refs/heads/new-branch')
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('fake-branch', 'new-branch', 'fake-github-pr-token')
      end.to raise_exception(StandardError)
    end

    it 'ensures new branch does not exist remotely' do
      expect(Fastlane::Actions).to receive(:sh).with('git', 'ls-remote', '--heads', 'origin', 'new-branch').once
      Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('fake-branch', 'new-branch', 'fake-github-pr-token')
    end

    it 'ensures repo is in specified branch' do
      expect(Fastlane::Actions::EnsureGitBranchAction).to receive(:run).with(branch: 'fake-branch').once
      Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('fake-branch', 'new-branch', 'fake-github-pr-token')
    end

    it 'ensures repo is in a clean state' do
      expect(Fastlane::Actions::EnsureGitStatusCleanAction).to receive(:run).with({}).once
      Fastlane::Helper::RevenuecatInternalHelper.validate_local_config_status_for_bump('fake-branch', 'new-branch', 'fake-github-pr-token')
    end
  end

  describe '.calculate_next_snapshot_version' do
    it 'calculates next version correctly with version with hotfix' do
      next_version = Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('1.11.1')
      expect(next_version).to eq('1.12.0-SNAPSHOT')
    end

    it 'calculates next version correctly with snapshot version' do
      next_version = Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('1.11.1-SNAPSHOT')
      expect(next_version).to eq('1.12.0-SNAPSHOT')
    end

    it 'calculates next version correctly with major relase' do
      next_version = Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('5.0.0')
      expect(next_version).to eq('5.1.0-SNAPSHOT')
    end

    it 'fails if given version without hotfix number' do
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('1.11')
      end.to raise_exception(StandardError)
    end

    it 'fails if given version with more than 3 numbers' do
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.calculate_next_snapshot_version('1.11.1.1')
      end.to raise_exception(StandardError)
    end
  end

  describe '.create_github_release' do
    let(:commit_hash) { 'fake-commit-hash' }
    let(:release_description) { 'fake-description' }
    let(:upload_assets) { ['./path-to/upload-asset-1.txt', './path-to/upload-asset-2.rb'] }
    let(:repo_name) { 'fake-repo-name' }
    let(:github_api_token) { 'fake-github-api-token' }
    let(:no_prerelease_version) { '1.11.0' }
    let(:prerelease_version) { '1.11.0-SNAPSHOT' }
    let(:server_url) { 'https://api.github.com' }

    before(:each) do
      allow(Fastlane::Actions).to receive(:last_git_commit_dict).and_return(commit_hash: commit_hash)
    end

    it 'calls SetGithubReleaseAction with appropriate parameters for non-prerelease version' do
      expect(Fastlane::Actions::SetGithubReleaseAction).to receive(:run).with(
        repository_name: "RevenueCat/fake-repo-name",
        api_token: github_api_token,
        name: no_prerelease_version,
        tag_name: no_prerelease_version,
        description: release_description,
        commitish: commit_hash,
        upload_assets: upload_assets,
        is_draft: false,
        is_prerelease: false,
        server_url: server_url
      )
      Fastlane::Helper::RevenuecatInternalHelper.create_github_release(
        no_prerelease_version,
        release_description,
        upload_assets,
        repo_name,
        github_api_token
      )
    end

    it 'calls SetGithubReleaseAction with appropriate parameters for prerelease version' do
      expect(Fastlane::Actions::SetGithubReleaseAction).to receive(:run).with(
        repository_name: "RevenueCat/fake-repo-name",
        api_token: github_api_token,
        name: prerelease_version,
        tag_name: prerelease_version,
        description: release_description,
        commitish: commit_hash,
        upload_assets: upload_assets,
        is_draft: false,
        is_prerelease: true,
        server_url: server_url
      )
      Fastlane::Helper::RevenuecatInternalHelper.create_github_release(
        prerelease_version,
        release_description,
        upload_assets,
        repo_name,
        github_api_token
      )
    end
  end

  describe '.replace_in' do
    require 'fileutils'

    let(:tmp_test_file_path) { './tmp_test_files/test_file.txt' }

    before(:each) do
      Dir.mkdir('tmp_test_files')
    end

    after(:each) do
      FileUtils.rm_rf('tmp_test_files')
    end

    it 'fails if new string is empty and allow_empty false' do
      expect(Fastlane::Actions).not_to receive(:sh)
      expect do
        Fastlane::Helper::RevenuecatInternalHelper.replace_in('1.11.0', '', tmp_test_file_path, allow_empty: false)
      end.to raise_exception(StandardError)
    end

    it 'changes old string with empty new string if allow_empty is true' do
      File.write(tmp_test_file_path, 'Testing removing=1.11.0, but not=1.11.1')
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('1.11.0', '', tmp_test_file_path, allow_empty: true)
      expect(File.read(tmp_test_file_path)).to eq('Testing removing=, but not=1.11.1')
    end

    it 'changes old string with new string' do
      File.write(tmp_test_file_path, 'Testing changing text=4.1.3-SNAPSHOT')
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('4.1.3-SNAPSHOT', '4.1.3', tmp_test_file_path)
      expect(File.read(tmp_test_file_path)).to eq('Testing changing text=4.1.3')
    end

    it 'changes multiple occurences of old string with new string' do
      File.write(tmp_test_file_path, "Testing changing text=4.1.3-SNAPSHOT and also\nversion=4.1.3-SNAPSHOT\nand again without spaces4.1.3-SNAPSHOT")
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('4.1.3-SNAPSHOT', '4.1.3', tmp_test_file_path)
      expect(File.read(tmp_test_file_path)).to eq("Testing changing text=4.1.3 and also\nversion=4.1.3\nand again without spaces4.1.3")
    end

    it 'does not change any text if old text not present in file' do
      contents = 'Testing 4.1.4'
      File.write(tmp_test_file_path, contents)
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('4.1.3', '4.4.0-SNAPSHOT', tmp_test_file_path)
      expect(File.read(tmp_test_file_path)).to eq(contents)
    end

    it 'does not change text that does not match exact old text with dots' do
      contents = '55413C0025B778E00ECCA5A'
      File.write(tmp_test_file_path, '55413C0025B778E00ECCA5A')
      Fastlane::Helper::RevenuecatInternalHelper.replace_in('4.1.3', '4.4.0-SNAPSHOT', tmp_test_file_path)
      expect(File.read(tmp_test_file_path)).to eq(contents)
    end
  end
end
