AppendPhcVersionIfNecessaryParams = Struct.new(
  :interactive,
  :append_on_confirmation,
  :append_hybrid_common_version,
  :include_prereleases,
  :hybrid_common_version,
  :new_version_number,
  :expected_version,
  keyword_init: true
)

describe Fastlane::Helper::VersioningHelper do
  before(:each) do
    allow(Fastlane::Actions).to receive(:git_branch).and_return('main')
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
    let(:get_commit_4_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_9a289e554fe384e6987b086fad047671058cf044.json") }
    end
    let(:get_commit_5_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_1625e195a117ad0435864dc8a561e6a0c6052bdf.json") }
    end
    let(:get_commit_923_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_9237147947bcbce00f36ae3ab51acccc54690782.json") }
    end
    let(:get_commit_592_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_5920c32646f918a2484da8aa38ccc5e9337cc449.json") }
    end
    let(:get_commit_323_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_32320acc1d6afae30a965d7add32700313123431.json") }
    end
    let(:get_commit_757_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_75763d3f1604aa5d633e70e46299b1f2813cb163.json") }
    end
    let(:duplicate_items_get_commit_2_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/duplicate_items_get_commit_sha_0e67cdb1c7582ce3e2fd00367acc24db6242c6d6.json") }
    end
    let(:breaking_get_commit_1_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/breaking_get_commit_sha_a72c0435ecf71248f311900475e881cc07ac2eaf.json") }
    end
    let(:no_label_get_commit_1_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/no_label_get_commit_sha_a72c0435ecf71248f311900475e881cc07ac2eaf.json") }
    end
    let(:get_commits_response_no_pr) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commits_since_last_release_commit_with_no_pr.json") }
    end
    let(:get_commit_no_items) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_4ceaceb20e700b92197daf8904f5c4e226625d8a.json") }
    end
    let(:get_commits_response_hybrid) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commits_since_last_release_hybrid.json") }
    end
    let(:purchases_android_releases) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/purchases_android_releases.json") }
    end
    let(:purchases_ios_releases) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/purchases_ios_releases.json") }
    end
    let(:versions_path) { "#{File.dirname(__FILE__)}/../test_files/VERSIONS.md" }
    let(:unity_versions_path) { "#{File.dirname(__FILE__)}/../test_files/VERSIONS_unity.md" }
    let(:empty_versions_path) { "#{File.dirname(__FILE__)}/../test_files/VERSIONS_empty.md" }
    let(:broken_versions_path) { "#{File.dirname(__FILE__)}/../test_files/VERSIONS_broken.md" }
    let(:hybrid_common_version) { '4.5.3' }

    let(:hashes_to_responses) do
      {
        'a72c0435ecf71248f311900475e881cc07ac2eaf' => get_commit_1_response,
        '0e67cdb1c7582ce3e2fd00367acc24db6242c6d6' => get_commit_2_response,
        'cfdd80f73d8c91121313d72227b4cbe283b57c1e' => get_commit_3_response,
        '9a289e554fe384e6987b086fad047671058cf044' => get_commit_4_response,
        '1625e195a117ad0435864dc8a561e6a0c6052bdf' => get_commit_5_response
      }
    end

    let(:hashes_to_responses_hybrid) do
      {
        '32320acc1d6afae30a965d7add32700313123431' => get_commit_323_response,
        '5920c32646f918a2484da8aa38ccc5e9337cc449' => get_commit_592_response,
        '9237147947bcbce00f36ae3ab51acccc54690782' => get_commit_923_response,
        '75763d3f1604aa5d633e70e46299b1f2813cb163' => get_commit_757_response
      }
    end

    it 'generates changelog automatically from github commits' do
      setup_commit_search_stubs(hashes_to_responses)
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        nil,
        nil
      )
      expect(changelog).to eq("### New Features\n" \
                              "* added a log when `autoSyncPurchases` is disabled (#1749) via aboedo (@aboedo)\n" \
                              "### RevenueCatUI\n" \
                              "* `Paywalls`: multi-package horizontal template (#2949) via Nacho Soto (@nachosoto)\n" \
                              "### Bugfixes\n" \
                              "* Fix replace version without prerelease modifiers (#1751) via Toni Rico (@tonidero)\n" \
                              "### Performance Improvements\n" \
                              "* `PostReceiptDataOperation`: replaced receipt `base64` with `hash` for cache key (#2199) via Nacho Soto (@nachosoto)")
    end

    it 'includes native dependencies links automatically' do
      setup_tag_stubs
      mock_commits_since_last_release("9237147947bcbce00f36ae3ab51acccc54690782", get_commits_response_hybrid)
      mock_native_releases
      hashes_to_responses_hybrid.each do |hash, response|
        allow(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(server_url: server_url,
                path: "/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:#{hash}",
                http_method: http_method,
                body: {},
                api_token: 'mock-github-token')
          .and_return(response)
      end
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('5.6.6').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_ios_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('4.15.4').once
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        hybrid_common_version,
        versions_path
      )
      expect(changelog).to eq("### Dependency Updates\n" \
                              "* [AUTOMATIC BUMP] Updates purchases-hybrid-common to 4.5.3 (#553) via RevenueCat Git Bot (@RCGitBot)\n" \
                              "\s\s* [Android 5.6.6](https://github.com/RevenueCat/purchases-android/releases/tag/5.6.6)\n" \
                              "\s\s* [iOS 4.15.4](https://github.com/RevenueCat/purchases-ios/releases/tag/4.15.4)\n" \
                              "\s\s* [iOS 4.15.3](https://github.com/RevenueCat/purchases-ios/releases/tag/4.15.3)")
    end

    it 'includes native dependencies links automatically. Also works for unity style VERSIONS.md' do
      setup_tag_stubs
      mock_commits_since_last_release("9237147947bcbce00f36ae3ab51acccc54690782", get_commits_response_hybrid)
      mock_native_releases
      hashes_to_responses_hybrid.each do |hash, response|
        allow(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(server_url: server_url,
                path: "/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:#{hash}",
                http_method: http_method,
                body: {},
                api_token: 'mock-github-token')
          .and_return(response)
      end
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('5.6.6').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_ios_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('4.15.4').once
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        hybrid_common_version,
        unity_versions_path
      )
      expect(changelog).to eq("### Dependency Updates\n" \
                              "* [AUTOMATIC BUMP] Updates purchases-hybrid-common to 4.5.3 (#553) via RevenueCat Git Bot (@RCGitBot)\n" \
                              "\s\s* [Android 5.6.6](https://github.com/RevenueCat/purchases-android/releases/tag/5.6.6)\n" \
                              "\s\s* [iOS 4.15.4](https://github.com/RevenueCat/purchases-ios/releases/tag/4.15.4)\n" \
                              "\s\s* [iOS 4.15.3](https://github.com/RevenueCat/purchases-ios/releases/tag/4.15.3)")
    end

    it 'handles empty VERSIONS.md' do
      setup_tag_stubs
      expect(FastlaneCore::UI).to receive(:error)
        .with("Can't detect iOS and Android version for version 4.5.3 of purchases-hybrid-common. Empty VERSIONS.md")
        .once
      mock_commits_since_last_release("9237147947bcbce00f36ae3ab51acccc54690782", get_commits_response_hybrid)
      hashes_to_responses_hybrid.each do |hash, response|
        allow(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(server_url: server_url,
                path: "/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:#{hash}",
                http_method: http_method,
                body: {},
                api_token: 'mock-github-token')
          .and_return(response)
      end
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        hybrid_common_version,
        empty_versions_path
      )
      expect(changelog).to eq("### Dependency Updates\n" \
                              "* [AUTOMATIC BUMP] Updates purchases-hybrid-common to 4.5.3 (#553) via RevenueCat Git Bot (@RCGitBot)")
    end

    it 'handles broken VERSIONS.md' do
      setup_tag_stubs
      expect(FastlaneCore::UI).to receive(:error)
        .with("Malformed iOS version - for version 4.5.3 of purchases-hybrid-common.")
        .once
      mock_commits_since_last_release("9237147947bcbce00f36ae3ab51acccc54690782", get_commits_response_hybrid)
      hashes_to_responses_hybrid.each do |hash, response|
        allow(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(server_url: server_url,
                path: "/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:#{hash}",
                http_method: http_method,
                body: {},
                api_token: 'mock-github-token')
          .and_return(response)
      end
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        hybrid_common_version,
        broken_versions_path
      )
      expect(changelog).to eq("### Dependency Updates\n" \
                              "* [AUTOMATIC BUMP] Updates purchases-hybrid-common to 4.5.3 (#553) via RevenueCat Git Bot (@RCGitBot)")
    end

    it 'includes native dependencies links automatically. only includes new versions' do
      hybrid_common_version = '4.5.3'
      setup_tag_stubs
      mock_commits_since_last_release("9237147947bcbce00f36ae3ab51acccc54690782", get_commits_response_hybrid)
      mock_native_releases
      hashes_to_responses_hybrid.each do |hash, response|
        allow(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(server_url: server_url,
                path: "/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:#{hash}",
                http_method: http_method,
                body: {},
                api_token: 'mock-github-token')
          .and_return(response)
      end
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('5.6.6').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_ios_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('4.15.4').once
      # Making the latest android version match the current one
      expect(File).to receive(:readlines).with(versions_path)
                                         .and_return(["| Version | iOS version | Android version | Common files version |\n",
                                                      "|---------|-------------|-----------------|----------------------|\n",
                                                      "| 4.5.3   | 4.15.2      | 5.6.6           | 4.5.2                |"])
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        hybrid_common_version,
        versions_path
      )
      expect(changelog).to eq("### Dependency Updates\n" \
                              "* [AUTOMATIC BUMP] Updates purchases-hybrid-common to 4.5.3 (#553) via RevenueCat Git Bot (@RCGitBot)\n" \
                              "\s\s* [iOS 4.15.4](https://github.com/RevenueCat/purchases-ios/releases/tag/4.15.4)\n" \
                              "\s\s* [iOS 4.15.3](https://github.com/RevenueCat/purchases-ios/releases/tag/4.15.3)")
    end

    it 'includes native dependencies links automatically. skips if no updates to native' do
      hybrid_common_version = '4.5.3'
      setup_tag_stubs
      mock_commits_since_last_release("9237147947bcbce00f36ae3ab51acccc54690782", get_commits_response_hybrid)
      mock_native_releases
      hashes_to_responses_hybrid.each do |hash, response|
        allow(Fastlane::Actions::GithubApiAction).to receive(:run)
          .with(server_url: server_url,
                path: "/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:#{hash}",
                http_method: http_method,
                body: {},
                api_token: 'mock-github-token')
          .and_return(response)
      end
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_android_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('5.6.6').once
      expect(Fastlane::Helper::UpdateHybridsVersionsFileHelper).to receive(:get_ios_version_for_hybrid_common_version)
        .with(hybrid_common_version).and_return('4.15.4').once
      # Making the latest android version match the current one
      expect(File).to receive(:readlines).with(versions_path)
                                         .and_return(["| Version | iOS version | Android version | Common files version |\n",
                                                      "|---------|-------------|-----------------|----------------------|\n",
                                                      "| 4.5.3   | 4.15.4      | 5.6.6           | 4.5.2                |"])
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        hybrid_common_version,
        versions_path
      )
      expect(changelog).to eq("### Dependency Updates\n" \
                              "* [AUTOMATIC BUMP] Updates purchases-hybrid-common to 4.5.3 (#553) via RevenueCat Git Bot (@RCGitBot)")
    end

    it 'sleeps between getting commits info if passing rate limit sleep' do
      setup_commit_search_stubs(hashes_to_responses)
      expect_any_instance_of(Object).to receive(:sleep).with(3).exactly(5).times
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        3,
        false,
        nil,
        nil
      )
      expect(changelog).to eq("### New Features\n" \
                              "* added a log when `autoSyncPurchases` is disabled (#1749) via aboedo (@aboedo)\n" \
                              "### RevenueCatUI\n" \
                              "* `Paywalls`: multi-package horizontal template (#2949) via Nacho Soto (@nachosoto)\n" \
                              "### Bugfixes\n" \
                              "* Fix replace version without prerelease modifiers (#1751) via Toni Rico (@tonidero)\n" \
                              "### Performance Improvements\n" \
                              "* `PostReceiptDataOperation`: replaced receipt `base64` with `hash` for cache key (#2199) via Nacho Soto (@nachosoto)")
    end

    it 'fails if it finds multiple commits with same sha' do
      setup_commit_search_stubs(hashes_to_responses)
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:0e67cdb1c7582ce3e2fd00367acc24db6242c6d6',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(duplicate_items_get_commit_2_response)
      expect do
        Fastlane::Helper::VersioningHelper.auto_generate_changelog(
          'mock-repo-name',
          'mock-github-token',
          0,
          false,
          nil,
          nil
        )
      end.to raise_exception(StandardError)
    end

    it 'breaking fix is added to breaking changes section' do
      setup_commit_search_stubs(hashes_to_responses)
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:a72c0435ecf71248f311900475e881cc07ac2eaf',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(breaking_get_commit_1_response)
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        nil,
        nil
      )
      expect(changelog).to eq("### Breaking Changes\n" \
                              "* added a log when `autoSyncPurchases` is disabled (#1749) via aboedo (@aboedo)\n" \
                              "### RevenueCatUI\n" \
                              "* `Paywalls`: multi-package horizontal template (#2949) via Nacho Soto (@nachosoto)\n" \
                              "### Bugfixes\n" \
                              "* Fix replace version without prerelease modifiers (#1751) via Toni Rico (@tonidero)\n" \
                              "### Performance Improvements\n" \
                              "* `PostReceiptDataOperation`: replaced receipt `base64` with `hash` for cache key (#2199) via Nacho Soto (@nachosoto)")
    end

    it 'change is classified as Other Changes if pr has no label' do
      setup_commit_search_stubs(hashes_to_responses)
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:a72c0435ecf71248f311900475e881cc07ac2eaf',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(no_label_get_commit_1_response)
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        nil,
        nil
      )
      expect(changelog).to eq("### RevenueCatUI\n" \
                              "* `Paywalls`: multi-package horizontal template (#2949) via Nacho Soto (@nachosoto)\n" \
                              "### Bugfixes\n" \
                              "* Fix replace version without prerelease modifiers (#1751) via Toni Rico (@tonidero)\n" \
                              "### Performance Improvements\n" \
                              "* `PostReceiptDataOperation`: replaced receipt `base64` with `hash` for cache key (#2199) via Nacho Soto (@nachosoto)\n" \
                              "### Other Changes\n" \
                              "* added a log when `autoSyncPurchases` is disabled (#1749) via aboedo (@aboedo)")
    end

    it 'change is classified as Other Changes if commit has no pr' do
      setup_tag_stubs
      mock_commits_since_last_release("4ceaceb20e700b92197daf8904f5c4e226625d8a", get_commits_response_no_pr)

      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:4ceaceb20e700b92197daf8904f5c4e226625d8a',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(get_commit_no_items)
      expect_any_instance_of(Object).not_to receive(:sleep)
      changelog = Fastlane::Helper::VersioningHelper.auto_generate_changelog(
        'mock-repo-name',
        'mock-github-token',
        0,
        false,
        nil,
        nil
      )
      expect(changelog).to eq("### Other Changes\n" \
                              "* Updating great support link via Miguel José Carranza Guisado (@MiguelCarranza)")
    end

    def mock_native_releases
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: 'repos/RevenueCat/purchases-android/releases?per_page=50',
              http_method: http_method,
              error_handlers: anything,
              api_token: 'mock-github-token')
        .and_return(purchases_android_releases)
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: 'repos/RevenueCat/purchases-ios/releases?per_page=50',
              http_method: http_method,
              error_handlers: anything,
              api_token: 'mock-github-token')
        .and_return(purchases_ios_releases)
    end
  end

  describe '.determine_next_version_using_labels' do
    let(:repo_name) { 'purchases-ios' }
    let(:server_url) { 'https://api.github.com' }
    let(:http_method) { 'GET' }
    let(:get_commits_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commits_since_last_release.json") }
    end
    let(:get_commits_response_patch) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commits_since_last_release_patch_changes.json") }
    end
    let(:get_commits_response_skip) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commits_since_last_release_skip_release.json") }
    end
    let(:get_commits_response_no_pr) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commits_since_last_release_commit_with_no_pr.json") }
    end
    let(:get_commits_response_no_pr_more_commits) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commits_since_last_release_commit_with_no_pr_with_more_commits.json") }
    end
    let(:get_feat_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_a72c0435ecf71248f311900475e881cc07ac2eaf.json") }
    end
    let(:get_fix_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_0e67cdb1c7582ce3e2fd00367acc24db6242c6d6.json") }
    end
    let(:get_paywalls_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_1625e195a117ad0435864dc8a561e6a0c6052bdf.json") }
    end
    let(:get_perf_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_9a289e554fe384e6987b086fad047671058cf044.json") }
    end
    let(:get_next_release_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_cfdd80f73d8c91121313d72227b4cbe283b57c1e.json") }
    end
    let(:get_breaking_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/breaking_get_commit_sha_a72c0435ecf71248f311900475e881cc07ac2eaf.json") }
    end
    let(:get_minor_label_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/minor_get_commit_sha_a72c0435ecf71248f311900475e881cc07ac2eaf.json") }
    end
    let(:get_ci_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_819dc620db5608fb952c852038a3560554161707.json") }
    end
    let(:get_build_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_7d77decbcc9098145d1efd4c2de078b6121c8906.json") }
    end
    let(:get_refactor_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_6d37c766b6da55dcab67c201c93ba3d4ca538e55.json") }
    end
    let(:get_duplicate_items_fix_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/duplicate_items_get_commit_sha_0e67cdb1c7582ce3e2fd00367acc24db6242c6d6.json") }
    end
    let(:get_release_commit_response) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_1285b6df6fb756d8b31337be9dabbf3ec5c0bbfe.json") }
    end
    let(:get_commit_no_items) do
      { body: File.read("#{File.dirname(__FILE__)}/../test_files/get_commit_sha_4ceaceb20e700b92197daf8904f5c4e226625d8a.json") }
    end

    let(:hashes_to_responses) do
      {
        'a72c0435ecf71248f311900475e881cc07ac2eaf' => get_feat_commit_response,
        '0e67cdb1c7582ce3e2fd00367acc24db6242c6d6' => get_fix_commit_response,
        '1625e195a117ad0435864dc8a561e6a0c6052bdf' => get_paywalls_commit_response,
        '9a289e554fe384e6987b086fad047671058cf044' => get_perf_commit_response,
        'cfdd80f73d8c91121313d72227b4cbe283b57c1e' => get_next_release_commit_response,
        '819dc620db5608fb952c852038a3560554161707' => get_ci_commit_response,
        '7d77decbcc9098145d1efd4c2de078b6121c8906' => get_build_commit_response,
        '6d37c766b6da55dcab67c201c93ba3d4ca538e55' => get_refactor_commit_response,
        '1285b6df6fb756d8b31337be9dabbf3ec5c0bbfe' => get_release_commit_response,
        '4ceaceb20e700b92197daf8904f5c4e226625d8a' => get_commit_no_items
      }
    end

    describe '#latest_version_number' do
      let(:git_tag_output) do
        <<~GIT_TAG
5.7.0
5.7.1
6.0.0-alpha.1
6.0.0-alpha.2
amazon-latest
latest
        GIT_TAG
      end
      let(:git_tag_output_with_build_metadata) do
        <<~GIT_TAG
5.7.0
5.7.1
6.0.0-alpha.1
6.0.0-alpha.2
6.0.0+3.2.1
amazon-latest
latest
        GIT_TAG
      end
      it 'finds latest version number' do
        allow(Fastlane::Actions).to receive(:sh).and_return(git_tag_output)

        latest_version = Fastlane::Helper::VersioningHelper.send(:latest_version_number)
        expect(latest_version).to eq("5.7.1")
      end

      it 'finds latest prerelease version number' do
        allow(Fastlane::Actions).to receive(:sh).and_return(git_tag_output)

        latest_version = Fastlane::Helper::VersioningHelper.send(:latest_version_number, include_prereleases: true)
        expect(latest_version).to eq("6.0.0-alpha.2")
      end

      it 'finds latest version number with build metadata' do
        allow(Fastlane::Actions).to receive(:sh).and_return(git_tag_output_with_build_metadata)

        latest_version = Fastlane::Helper::VersioningHelper.send(:latest_version_number, include_prereleases: false)
        expect(latest_version).to eq("6.0.0+3.2.1")
      end
    end

    it 'determines next version as patch correctly' do
      setup_commit_search_stubs(hashes_to_responses)
      mock_commits_since_last_release('6d37c766b6da55dcab67c201c93ba3d4ca538e55', get_commits_response_patch)
      expect_any_instance_of(Object).not_to receive(:sleep)
      next_version, type_of_bump = Fastlane::Helper::VersioningHelper.determine_next_version_using_labels(
        'mock-repo-name',
        'mock-github-token',
        0,
        false
      )
      expect(next_version).to eq("1.11.1")
      expect(type_of_bump).to eq(:patch)
    end

    it 'skips next version if no release is needed' do
      setup_commit_search_stubs(hashes_to_responses)
      mock_commits_since_last_release('1285b6df6fb756d8b31337be9dabbf3ec5c0bbfe', get_commits_response_skip)
      expect_any_instance_of(Object).not_to receive(:sleep)
      next_version, type_of_bump = Fastlane::Helper::VersioningHelper.determine_next_version_using_labels(
        'mock-repo-name',
        'mock-github-token',
        0,
        false
      )
      expect(next_version).to eq("1.11.0")
      expect(type_of_bump).to eq(:skip)
    end

    it 'determines next version as minor correctly' do
      setup_commit_search_stubs(hashes_to_responses)

      expect_any_instance_of(Object).not_to receive(:sleep)
      next_version, type_of_bump = Fastlane::Helper::VersioningHelper.determine_next_version_using_labels(
        'mock-repo-name',
        'mock-github-token',
        0,
        false
      )
      expect(next_version).to eq("1.12.0")
      expect(type_of_bump).to eq(:minor)
    end

    it 'determine next version as minor if labeled as minor' do
      setup_commit_search_stubs(hashes_to_responses)

      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:a72c0435ecf71248f311900475e881cc07ac2eaf',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(get_minor_label_commit_response)
      expect_any_instance_of(Object).not_to receive(:sleep)
      next_version, type_of_bump = Fastlane::Helper::VersioningHelper.determine_next_version_using_labels(
        'mock-repo-name',
        'mock-github-token',
        0,
        false
      )
      expect(next_version).to eq("1.12.0")
      expect(type_of_bump).to eq(:minor)
    end

    it 'determines next version as major correctly' do
      setup_commit_search_stubs(hashes_to_responses)

      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:a72c0435ecf71248f311900475e881cc07ac2eaf',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(get_breaking_commit_response)
      expect_any_instance_of(Object).not_to receive(:sleep)
      next_version, type_of_bump = Fastlane::Helper::VersioningHelper.determine_next_version_using_labels(
        'mock-repo-name',
        'mock-github-token',
        0,
        false
      )
      expect(next_version).to eq("2.0.0")
      expect(type_of_bump).to eq(:major)
    end

    it 'sleeps between getting commits info if passing rate limit sleep' do
      setup_commit_search_stubs(hashes_to_responses)

      expect_any_instance_of(Object).to receive(:sleep).with(3).exactly(5).times
      next_version, type_of_bump = Fastlane::Helper::VersioningHelper.determine_next_version_using_labels(
        'mock-repo-name',
        'mock-github-token',
        3,
        false
      )
      expect(next_version).to eq("1.12.0")
      expect(type_of_bump).to eq(:minor)
    end

    it 'fails if it finds multiple commits with same sha' do
      setup_commit_search_stubs(hashes_to_responses)

      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:0e67cdb1c7582ce3e2fd00367acc24db6242c6d6',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(get_duplicate_items_fix_commit_response)
      expect do
        Fastlane::Helper::VersioningHelper.determine_next_version_using_labels(
          'mock-repo-name',
          'mock-github-token',
          0,
          false
        )
      end.to raise_exception(StandardError)
    end

    it 'skips if it finds commit without a pr associated' do
      setup_commit_search_stubs(hashes_to_responses)
      mock_commits_since_last_release('4ceaceb20e700b92197daf8904f5c4e226625d8a', get_commits_response_no_pr)
      expect_any_instance_of(Object).not_to receive(:sleep)
      next_version, type_of_bump = Fastlane::Helper::VersioningHelper.determine_next_version_using_labels(
        'mock-repo-name',
        'mock-github-token',
        0,
        false
      )
      expect(next_version).to eq("1.11.0")
      expect(type_of_bump).to eq(:skip)
    end

    it 'ignores commits without associated prs' do
      setup_commit_search_stubs(hashes_to_responses)

      mock_commits_since_last_release('885cfa2d3d570c7427ad6581bc8e4e6c4baf82e4', get_commits_response_no_pr_more_commits)
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: '/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:a72c0435ecf71248f311900475e881cc07ac2eaf',
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(get_breaking_commit_response)
      expect_any_instance_of(Object).not_to receive(:sleep)
      next_version, type_of_bump = Fastlane::Helper::VersioningHelper.determine_next_version_using_labels(
        'mock-repo-name',
        'mock-github-token',
        0,
        false
      )
      expect(next_version).to eq("2.0.0")
      expect(type_of_bump).to eq(:major)
    end
  end

  describe '.increase_version' do
    it 'increases patch version number' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3', :patch, false)
      expect(next_version).to eq('1.2.4')
    end

    it 'increases minor version number' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3', :minor, false)
      expect(next_version).to eq('1.3.0')
    end

    it 'increases major version number' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3', :major, false)
      expect(next_version).to eq('2.0.0')
    end

    it 'increases minor snapshot version number' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3', :minor, true)
      expect(next_version).to eq('1.3.0-SNAPSHOT')
    end

    it 'increases major snapshot version number' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3', :major, true)
      expect(next_version).to eq('2.0.0-SNAPSHOT')
    end

    it 'increasing patch version number ignores build metadata' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3+3.2.1', :patch, false)
      expect(next_version).to eq('1.2.4')
    end

    it 'increasing minor version number ignores build metadata' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3+3.2.1', :minor, false)
      expect(next_version).to eq('1.3.0')
    end

    it 'increasing major version number ignores build metadata' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3+3.2.1', :major, false)
      expect(next_version).to eq('2.0.0')
    end

    it 'increasing minor snapshot version number ignores build metadata' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3+3.2.1', :minor, true)
      expect(next_version).to eq('1.3.0-SNAPSHOT')
    end

    it 'increasing major snapshot version number ignores build metadata' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3+3.2.1', :major, true)
      expect(next_version).to eq('2.0.0-SNAPSHOT')
    end

    it 'keeps version with snapshot but removing alpha modifier if it appears' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3-alpha.1', :major, true)
      expect(next_version).to eq('1.2.3-SNAPSHOT')
    end

    it 'keeps version with snapshot but removing beta modifier if it appears' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3-beta.1', :minor, true)
      expect(next_version).to eq('1.2.3-SNAPSHOT')
    end

    it 'keeps version with snapshot but removing rc modifier if it appears' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3-beta.1', :patch, true)
      expect(next_version).to eq('1.2.3-SNAPSHOT')
    end

    it 'keeps version but removing rc modifier if it appears' do
      next_version = Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3-beta.1', :patch, false)
      expect(next_version).to eq('1.2.3')
    end

    it 'fails if given snapshot version to bump' do
      expect do
        Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3-SNAPSHOT', :patch, false)
      end.to raise_exception(StandardError)
    end

    it 'fails if given unsupported version to bump' do
      expect do
        Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3-alpha', :patch, false)
      end.to raise_exception(StandardError)
    end

    it 'fails if given version with both prerelease modifier and build metadata to bump' do
      expect do
        Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3-rc.1+2.3.1', :patch, false)
      end.to raise_exception(StandardError)
    end

    it 'fails if given version with incorrect build metadata to bump' do
      expect do
        Fastlane::Helper::VersioningHelper.calculate_next_version('1.2.3+meta data', :patch, false)
      end.to raise_exception(StandardError)
    end
  end

  describe '.detect_bump_type' do
    it 'correctly detects patch bumps' do
      bump_type = Fastlane::Helper::VersioningHelper.detect_bump_type('1.2.3', '1.2.4')
      expect(bump_type).to eq(:patch)
    end

    it 'correctly detects minor bumps' do
      bump_type = Fastlane::Helper::VersioningHelper.detect_bump_type('1.2.3', '1.3.0')
      expect(bump_type).to eq(:minor)
    end

    it 'correctly detects major bumps' do
      bump_type = Fastlane::Helper::VersioningHelper.detect_bump_type('1.2.3', '2.0.0')
      expect(bump_type).to eq(:major)
    end

    it 'correctly detects no version bump' do
      bump_type = Fastlane::Helper::VersioningHelper.detect_bump_type('1.2.3', '1.2.3')
      expect(bump_type).to eq(:none)
    end

    it 'fails if incompatible versions' do
      expect(FastlaneCore::UI).to receive(:error)
        .with("Can't detect bump type because version 1.2.3 and 1.2 have a different format")
        .once
      bump_type = Fastlane::Helper::VersioningHelper.detect_bump_type('1.2.3', '1.2')
      expect(bump_type).to eq(:none)
    end

    it 'fails if versions don\'t have 3 segments' do
      expect(FastlaneCore::UI).to receive(:error)
        .with("Can't detect bump type because versions don't follow format x.y.z")
        .once
      bump_type = Fastlane::Helper::VersioningHelper.detect_bump_type('1.3', '1.2')
      expect(bump_type).to eq(:none)
    end
  end

  describe 'append_phc_version_if_necessary' do
    params = [
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0+12.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: nil,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0+12.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: true,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0+12.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: false,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: true,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: " ",
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: nil,
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: " ",
        expected_version: " "
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: nil,
        expected_version: nil
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0-SNAPSHOT",
        expected_version: "2.0.0-SNAPSHOT"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0-alpha.1",
        expected_version: "2.0.0-alpha.1"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0-beta.1",
        expected_version: "2.0.0-beta.1"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0+meta",
        expected_version: "2.0.0+meta"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: true,
        append_on_confirmation: true,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0+",
        expected_version: "2.0.0+"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: nil,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: true,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0+12.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: false,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: true,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: " ",
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: nil,
        new_version_number: "2.0.0",
        expected_version: "2.0.0"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: " ",
        expected_version: " "
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: nil,
        expected_version: nil
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0-SNAPSHOT",
        expected_version: "2.0.0-SNAPSHOT"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0-alpha.1",
        expected_version: "2.0.0-alpha.1"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0-beta.1",
        expected_version: "2.0.0-beta.1"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0+meta",
        expected_version: "2.0.0+meta"
      ),
      AppendPhcVersionIfNecessaryParams.new(
        interactive: false,
        append_on_confirmation: false,
        append_hybrid_common_version: nil,
        include_prereleases: false,
        hybrid_common_version: "12.0.0",
        new_version_number: "2.0.0+",
        expected_version: "2.0.0+"
      )
    ]

    params.each_with_index do |param, i|
      it "#{i} - params: #{param}" do
          allow(FastlaneCore::UI).to receive(:interactive?).and_return(param.interactive)
        allow(FastlaneCore::UI).to receive(:confirm).with(anything).and_return(param.append_on_confirmation)

        actual_version = Fastlane::Helper::VersioningHelper.append_phc_version_if_necessary(
          param.append_hybrid_common_version,
          param.include_prereleases,
          param.hybrid_common_version,
          param.new_version_number
        )

          expect(actual_version).to eq(param.expected_version)
      end
    end
  end

  def setup_tag_stubs
    allow(Fastlane::Actions).to receive(:sh).with('git fetch --tags -f')
    allow(Fastlane::Actions).to receive(:sh)
      .with("git tag", log: false)
      .and_return("0.1.0\n0.1.1\n1.11.0\n1.1.1.1\n1.1.1-alpha.1\n1.10.1")
  end

  def setup_commit_search_stubs(hashes_to_responses)
    setup_tag_stubs
    mock_commits_since_last_release('cfdd80f73d8c91121313d72227b4cbe283b57c1e', get_commits_response)
    hashes_to_responses.each do |hash, response|
      allow(Fastlane::Actions::GithubApiAction).to receive(:run)
        .with(server_url: server_url,
              path: "/search/issues?q=repo:RevenueCat/mock-repo-name+is:pr+base:main+SHA:#{hash}",
              http_method: http_method,
              body: {},
              api_token: 'mock-github-token')
        .and_return(response)
    end
  end

  def mock_commits_since_last_release(last_commit_hash, response)
    allow(Fastlane::Actions::LastGitCommitAction).to receive(:run)
      .and_return(commit_hash: last_commit_hash)
    allow(Fastlane::Actions::GithubApiAction).to receive(:run)
      .with(server_url: server_url,
            path: "/repos/RevenueCat/mock-repo-name/compare/1.11.0...#{last_commit_hash}",
            http_method: http_method,
            body: {},
            api_token: 'mock-github-token')
      .and_return(response)
  end
end
