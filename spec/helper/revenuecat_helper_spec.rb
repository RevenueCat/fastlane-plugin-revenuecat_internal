describe Fastlane::Helper::RevenuecatHelper do
  describe '.replace_version_number' do
    let(:file_to_update_1) { './test_files/file_to_update_1.txt' }
    let(:file_to_update_2) { './test_files/file_to_update_2.txt' }
    let(:file_to_update_without_prerelease_modifiers_3) { './test_files/file_to_update_3.txt' }
    let(:file_to_update_without_prerelease_modifiers_4) { './test_files/file_to_update_4.txt' }

    it 'updates previous version number with new version number when no prerelease modifiers are passed' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_1).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_2).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_3).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_4).once

      Fastlane::Helper::RevenuecatHelper.replace_version_number('1.11.0',
                                                                '1.12.0',
                                                                [file_to_update_1,
                                                                 file_to_update_2],
                                                                [file_to_update_without_prerelease_modifiers_3,
                                                                 file_to_update_without_prerelease_modifiers_4])
    end

    it 'updates previous version number with new version number when current version has prerelease modifiers' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0-SNAPSHOT|1.12.0|', file_to_update_1).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0-SNAPSHOT|1.12.0|', file_to_update_2).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_3).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_4).once

      Fastlane::Helper::RevenuecatHelper.replace_version_number('1.11.0-SNAPSHOT',
                                                                '1.12.0',
                                                                [file_to_update_1,
                                                                 file_to_update_2],
                                                                [file_to_update_without_prerelease_modifiers_3,
                                                                 file_to_update_without_prerelease_modifiers_4])
    end

    it 'updates previous version number with new version number when new version has prerelease modifiers' do
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0-SNAPSHOT|', file_to_update_1).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0-SNAPSHOT|', file_to_update_2).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_3).once
      expect(Fastlane::Actions).to receive(:sh).with('sed', '-i', '.bck', 's|1\\.11.0|1.12.0|', file_to_update_without_prerelease_modifiers_4).once

      Fastlane::Helper::RevenuecatHelper.replace_version_number('1.11.0',
                                                                '1.12.0-SNAPSHOT',
                                                                [file_to_update_1,
                                                                 file_to_update_2],
                                                                [file_to_update_without_prerelease_modifiers_3,
                                                                 file_to_update_without_prerelease_modifiers_4])
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
      changelog = Fastlane::Helper::RevenuecatHelper.auto_generate_changelog('mock-repo-name',
                                                                             'mock-github-token',
                                                                             0)
      expect(changelog).to eq("* Prepare next version: 4.8.0-SNAPSHOT (#1750) via RevenueCat Releases (@revenuecat-ops)\n" \
                              "* Fix replace version without prerelease modifiers (#1751) via Toni Rico (@tonidero)\n" \
                              "* added a log when `autoSyncPurchases` is disabled (#1749) via aboedo (@aboedo)")
    end

    it 'sleeps between getting commits info if passing rate limit sleep' do
      setup_stubs
      expect_any_instance_of(Object).to receive(:sleep).with(3).exactly(3).times
      changelog = Fastlane::Helper::RevenuecatHelper.auto_generate_changelog('mock-repo-name',
                                                                             'mock-github-token',
                                                                             3)
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
        Fastlane::Helper::RevenuecatHelper.auto_generate_changelog('mock-repo-name',
                                                                   'mock-github-token',
                                                                   0)
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
      Fastlane::Helper::RevenuecatHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
    end

    it 'opens editor to edit prepopulated changelog' do
      expect_any_instance_of(Object).to receive(:system).with(editor, changelog_latest_path).once
      Fastlane::Helper::RevenuecatHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
    end

    it 'fails if prepopulated changelog is empty' do
      expect(File).not_to receive(:write)
      expect do
        Fastlane::Helper::RevenuecatHelper.edit_changelog('', changelog_latest_path, editor)
      end.to raise_exception(StandardError)
    end

    it 'fails if user cancels on confirmation to open editor' do
      expect(File).not_to receive(:write)
      allow(FastlaneCore::UI).to receive(:confirm).with('Open CHANGELOG.latest.md in \'vim\'? (No will quit this process)').and_return(false)
      expect do
        Fastlane::Helper::RevenuecatHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
      end.to raise_exception(StandardError)
    end

    it 'asks for confirmation if prepopulated changelog remains the same after editor opening' do
      allow(File).to receive(:read).with(changelog_latest_path).and_return(prepopulated_changelog)
      expect(FastlaneCore::UI).to receive(:confirm)
        .with('You may have opened the changelog in a visual editor. Enter \'y\' when changes are saved or \'n\' to cancel').and_return(true).once
      Fastlane::Helper::RevenuecatHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
    end

    it 'fails if confirmation if prepopulated changelog remains the same after editor opening' do
      allow(File).to receive(:read).with(changelog_latest_path).and_return(prepopulated_changelog)
      expect(FastlaneCore::UI).to receive(:confirm)
        .with('You may have opened the changelog in a visual editor. Enter \'y\' when changes are saved or \'n\' to cancel').and_return(false).once
      expect do
        Fastlane::Helper::RevenuecatHelper.edit_changelog(prepopulated_changelog, changelog_latest_path, editor)
      end.to raise_exception(StandardError)
    end
  end
end
