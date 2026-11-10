describe Fastlane::Actions::CreateHotfixAction do
  let(:repo_name) { 'purchases-android' }
  let(:github_pr_token) { 'mock-github-pr-token' }
  let(:fix_sha) { 'f1x5ha' }
  let(:tag_commit) { 't4gc0mm1t' }
  let(:changelog_latest_path) { './CHANGELOG.latest.md' }
  let(:changelog_path) { './CHANGELOG.md' }
  let(:files_to_update) { { './.version' => ['{x}'] } }
  let(:labels) { [{ 'name' => 'pr:fix' }] }
  let(:base_ref) { 'main' }
  let(:merged_at) { '2026-10-30T10:00:00Z' }
  let(:tags) { ['10.1.0', '10.2.0', '10.3.0', '11.0.0'] }
  let(:interactive) { false }
  let(:local_release_branch) { '' }
  let(:remote_release_branch) { '' }
  let(:release_branch_commits) { [] }
  let(:cherry_pick_trailer) { "(cherry picked from commit #{fix_sha})" }
  let(:remote_base_branch_sha) { nil }
  let(:create_ref_status) { 201 }
  let(:open_release_prs) { [] }
  let(:open_changelog_prs) { [] }
  let(:main_changelog) { "## 11.0.0\n* New\n\n## 10.3.0\n* Old\n" }
  let(:changelog_pr_url) { 'https://github.com/RevenueCat/purchases-android/pull/457' }
  let(:failing_commands) { [] }
  let(:worktree) { end_with('/worktree') }
  let(:changelog_push) { ['git', '-C', worktree, '-c', 'core.hooksPath=/dev/null', 'push', '--force', 'origin', 'HEAD:refs/heads/changelog/10.2.1'] }
  let(:default_branch) { 'main' }
  let(:fix_already_in_tag) { false }
  let(:unmerged_files) { '' }
  let(:sh_calls) { [] }
  let(:api_calls) { [] }
  let(:release_pr_url) { 'https://github.com/RevenueCat/purchases-android/pull/456' }
  let(:published_dependency_releases) { ['purchases-ios/4.5.1'] }
  let(:changed_files) { " M build.gradle\n" }

  let(:pull_request) do
    {
      'number' => 123,
      'title' => 'Fix the bug',
      'user' => { 'login' => 'jane-doe' },
      'labels' => labels,
      'merged_at' => merged_at,
      'merge_commit_sha' => fix_sha,
      'base' => { 'ref' => base_ref, 'repo' => { 'default_branch' => default_branch } }
    }
  end

  before(:each) do
    @remote_base_branch_sha = remote_base_branch_sha
    allow(FastlaneCore::UI).to receive(:interactive?).and_return(interactive)
    allow(FastlaneCore::UI).to receive(:confirm).and_return(true)
    allow(Fastlane::Actions::EnsureGitStatusCleanAction).to receive(:run)
    allow(Fastlane::Actions).to receive(:sh) do |*command, **options|
      sh_calls << command
      if failing_commands.any? { |failing| RSpec::Support::FuzzyMatcher.values_match?(failing, command) } || (command.first(4) == ['git', 'merge-base', '--is-ancestor', fix_sha] && !fix_already_in_tag)
        FastlaneCore::UI.user_error!("#{command.join(' ')} failed") unless options[:error_callback]
        options[:error_callback].call('failed')
        ''
      else
        sh_output(command)
      end
    end
    allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry) do |**params|
      api_calls << params
      api_response(params)
    end
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with('./.version').and_return(true)
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with('./.version').and_return("10.2.0\n")
    allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:replace_version_number)
    allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:write_changelog)
    allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:attach_changelog_to_main)
    allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:commit_current_changes)
    allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:insert_old_version_changelog_in_current_branch)
    allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr).and_return(release_pr_url)
    allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr).with('Changelog update for 10.2.1', any_args).and_return(changelog_pr_url)
  end

  def sh_output(command)
    case command
    when ['git', 'tag'] then tags.join("\n")
    when ['git', 'log', '-1', '--format=%an', fix_sha] then "Jane Doe\n"
    when ['git', 'log', '--format=%s%x1f%b%x1e', '10.2.0..HEAD']
      release_branch_commits.map { |subject, body| "#{subject}\x1f#{body}\x1e" }.join("\n")
    when ['git', 'rev-parse', '--abbrev-ref', 'HEAD'] then "main\n"
    when ['git', 'diff', '--name-only', '--diff-filter=U'] then unmerged_files
    when ['git', 'status', '--porcelain'] then changed_files
    when ['git', 'show', "origin/#{default_branch}:#{changelog_path}"] then main_changelog
    else
      if command.first(3) == ['git', 'rev-list', '-n']
        "#{tag_commit}\n"
      elsif command.first(3) == ['git', 'branch', '--list']
        local_release_branch
      elsif command.first(4) == ['git', 'ls-remote', '--heads', 'origin']
        remote_release_branch
      else
        ''
      end
    end
  end

  def api_response(params)
    path = params[:path]
    case [params[:http_method], path]
    when ['GET', '/repos/RevenueCat/purchases-android']
      { status: 200, json: { 'default_branch' => default_branch } }
    when ['GET', '/repos/RevenueCat/purchases-android/pulls/123']
      { status: 200, json: pull_request }
    when ['POST', '/repos/RevenueCat/purchases-android/git/refs']
      create_ref_response(params[:body][:sha])
    when ['POST', '/repos/RevenueCat/purchases-android/issues/123/comments']
      { status: 201, json: {} }
    else
      if (release = path.match(%r{\A/repos/RevenueCat/([^/]+)/releases/tags/(.+)\z}))
        { status: published_dependency_releases.include?("#{release[1]}/#{release[2]}") ? 200 : 404, json: {} }
      elsif path.start_with?('/repos/RevenueCat/purchases-android/git/ref/heads/hotfix/')
        base_branch_ref_response
      elsif path.start_with?('/repos/RevenueCat/purchases-android/pulls?')
        { status: 200, json: open_prs(path) }
      else
        raise "Unexpected API call: #{params[:http_method]} #{path}"
      end
    end
  end

  def open_prs(path)
    path.include?('changelog%2F') ? open_changelog_prs : open_release_prs
  end

  def base_branch_ref_response
    { status: 200, json: { 'object' => { 'sha' => @remote_base_branch_sha } } }
  end

  def create_ref_response(sha)
    @remote_base_branch_sha ||= tag_commit if create_ref_status == 422
    return { status: 422, json: {} } if @remote_base_branch_sha

    { status: 201, json: { 'object' => { 'sha' => sha } } }
  end

  def run_action(version: '10.2.0', dry_run: false, files_without_prerelease_modifiers: {}, pr_number: 123, update_dependencies: nil, dependency_releases: {})
    Fastlane::Actions::CreateHotfixAction.run(
      repo_name: repo_name,
      pr_number: pr_number,
      update_dependencies: update_dependencies,
      dependency_releases: dependency_releases,
      version: version,
      changelog_latest_path: changelog_latest_path,
      changelog_path: changelog_path,
      files_to_update: files_to_update,
      files_to_update_without_prerelease_modifiers: files_without_prerelease_modifiers,
      files_to_update_on_latest_stable_releases: {},
      github_pr_token: github_pr_token,
      dry_run: dry_run
    )
  end

  def expect_user_error(message, version: '10.2.0')
    expect { run_action(version: version) }.to raise_error(FastlaneCore::Interface::FastlaneError, message)
  end

  def comments
    api_calls.select { |params| params[:path].end_with?('/issues/123/comments') }.map { |params| params[:body][:body] }
  end

  describe 'a new hotfix' do
    it 'creates the base branch, cherry-picks the fix, bumps the version and opens the release PR' do
      expected_changelog = "## RevenueCat SDK\n### 🐞 Bugfixes\n* Fix the bug (#123) via Jane Doe (@jane-doe)"
      allow(Fastlane::UI).to receive(:success)

      expect(run_action).to eq(release_pr_url)

      expect(api_calls).to include(hash_including(http_method: 'POST',
                                                  path: '/repos/RevenueCat/purchases-android/git/refs',
                                                  body: { ref: 'refs/heads/hotfix/10.2.0', sha: tag_commit }))
      expect(sh_calls).to include(['git', 'checkout', '-b', 'release/10.2.1', '10.2.0'])
      expect(sh_calls).to include(['git', 'cherry-pick', '-x', fix_sha])
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:replace_version_number)
        .with('10.2.0', '10.2.1', files_to_update, {}, {})
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:write_changelog)
        .with(expected_changelog, changelog_latest_path)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:attach_changelog_to_main)
        .with('10.2.1', changelog_latest_path, changelog_path)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:commit_current_changes)
        .with('Version bump for 10.2.1')
      expect(sh_calls).to include(['git', 'push', '--set-upstream', 'origin', 'release/10.2.1'])
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr)
        .with('Release/10.2.1', "Hotfix of #123 on 10.2.0. After the deploy, merge #{changelog_pr_url}.\n\n#{expected_changelog}", repo_name, 'hotfix/10.2.0', 'release/10.2.1', github_pr_token, labels: ['pr:next_release'])
      expect(sh_calls).to include(['git', 'worktree', 'add', '--no-checkout', '--detach', worktree, 'origin/main'])
      expect(sh_calls.select { |command| command.first(2) == ['git', 'checkout'] }).to eq([['git', 'checkout', '-b', 'release/10.2.1', '10.2.0']])
      expect(sh_calls).to include(['git', '-C', worktree, '-c', 'core.hooksPath=/dev/null', 'checkout', 'HEAD', '--', changelog_path])
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:insert_old_version_changelog_in_current_branch)
        .with('10.2.1', "#{expected_changelog}\n", end_with(File.join('worktree', changelog_path)))
      expect(sh_calls).to include(['git', '-C', worktree, '-c', 'core.hooksPath=/dev/null', 'commit', '-m', 'Changelog update for 10.2.1', '--', changelog_path])
      expect(sh_calls).to include(changelog_push)
      expect(sh_calls).to include(['git', 'worktree', 'remove', '--force', worktree])
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr)
        .with('Changelog update for 10.2.1', "Adds 10.2.1 to CHANGELOG.md. Merge it once 10.2.1 is deployed.",
              repo_name, 'main', 'changelog/10.2.1', github_pr_token, labels: ['pr:other', 'pr:changelog_ignore'], team_reviewers: [])
      next_steps = "Approve #{release_pr_url} but don't merge it: approval tags 10.2.1, then CircleCI deploys it and merges the PR into `hotfix/10.2.0`. " \
                   "Then delete `hotfix/10.2.0` and merge #{changelog_pr_url}. " \
                   "RELEASING.md lists any steps specific to this repo."
      expect(comments).to eq(["Hotfix release PR for 10.2.0: #{release_pr_url}\n\n#{next_steps}"])
      expect(Fastlane::UI).to have_received(:success).with("Hotfix release PR: #{release_pr_url}\n#{next_steps}")
    end

    it 'opens the changelog PR before the release PR' do
      run_action

      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr).with('Changelog update for 10.2.1', any_args).ordered
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr).with('Release/10.2.1', any_args).ordered
    end

    context 'when the changelog PR cannot be opened' do
      let(:failing_commands) { [changelog_push] }

      it 'still opens the release PR and asks to add the entry by hand' do
        expect(run_action).to eq(release_pr_url)

        expect(comments.first).to include("Then delete `hotfix/10.2.0` and add 10.2.1 to `CHANGELOG.md` on main.")
        expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr)
          .with('Release/10.2.1', start_with('Hotfix of #123 on 10.2.0. After the deploy, add 10.2.1 to `CHANGELOG.md` on main.'), any_args)
        expect(sh_calls).to include(['git', 'worktree', 'remove', '--force', worktree])
      end
    end

    it 'asks to add the entry by hand when the GitHub API raises' do
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr).with('Changelog update for 10.2.1', any_args).and_raise(SocketError, 'getaddrinfo failed')

      expect(run_action).to eq(release_pr_url)

      expect(comments.first).to include("add 10.2.1 to `CHANGELOG.md` on main")
    end

    it 'asks to add the entry by hand when GitHub does not create the changelog PR' do
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr).with('Changelog update for 10.2.1', any_args).and_return(nil)
      allow(Fastlane::UI).to receive(:success)

      run_action

      expect(sh_calls).to include(changelog_push)
      expect(Fastlane::UI).to have_received(:success).with(include("add 10.2.1 to `CHANGELOG.md` on main"))
    end

    context 'when the default branch has no changelog' do
      let(:failing_commands) { [['git', 'show', "origin/main:#{changelog_path}"]] }

      it 'still opens the release PR and asks to add the entry by hand' do
        expect(run_action).to eq(release_pr_url)

        expect(comments.first).to include("add 10.2.1 to `CHANGELOG.md` on main")
      end
    end

    context 'when the default branch is not main' do
      let(:default_branch) { 'develop' }
      let(:base_ref) { 'develop' }

      it 'opens the changelog PR into it' do
        run_action

        expect(sh_calls).to include(['git', 'worktree', 'add', '--no-checkout', '--detach', worktree, 'origin/develop'])
        expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr)
          .with('Changelog update for 10.2.1', anything, repo_name, 'develop', 'changelog/10.2.1', github_pr_token, labels: ['pr:other', 'pr:changelog_ignore'], team_reviewers: [])
      end
    end

    context 'when the changelog worktree cannot be added' do
      let(:failing_commands) { [['git', 'worktree', 'add', '--no-checkout', '--detach', worktree, 'origin/main']] }

      it 'still opens the release PR' do
        expect(run_action).to eq(release_pr_url)

        expect(sh_calls).to include(['git', 'worktree', 'remove', '--force', worktree])
        expect(comments.first).to include("add 10.2.1 to `CHANGELOG.md` on main")
      end
    end

    context 'when the changelog commit fails' do
      let(:failing_commands) { [['git', '-C', worktree, '-c', 'core.hooksPath=/dev/null', 'commit', '-m', 'Changelog update for 10.2.1', '--', changelog_path]] }

      it 'discards the CHANGELOG.md edit and still opens the release PR' do
        expect(run_action).to eq(release_pr_url)

        expect(sh_calls).to include(['git', 'worktree', 'remove', '--force', worktree])
        expect(comments.first).to include("add 10.2.1 to `CHANGELOG.md` on main")
      end
    end

    context 'when a rerun finds the changelog PR but no release PR' do
      let(:open_changelog_prs) { [{ 'html_url' => changelog_pr_url }] }

      it 'links the existing changelog PR in the comment' do
        run_action

        expect(Fastlane::Helper::RevenuecatInternalHelper).not_to have_received(:create_pr).with('Changelog update for 10.2.1', any_args)
        expect(comments.first).to include("merge #{changelog_pr_url}")
      end
    end

    context 'when main lists only versions that start the same' do
      let(:main_changelog) { "## 10.2.10\n* Later\n\n## 10.2.1-beta.1\n* Beta\n\n### 10.2.1\n* Not a header\n" }

      it 'still opens the changelog PR' do
        run_action

        expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr).with('Changelog update for 10.2.1', any_args)
      end
    end

    context 'when main already lists the version' do
      let(:main_changelog) { "## 11.0.0\n* New\n\n## 10.2.1 \n* Fix\n" }

      it 'opens no changelog PR and leaves it out of the next steps' do
        allow(Fastlane::UI).to receive(:success)

        run_action

        expect(sh_calls).not_to include(include('changelog/10.2.1'))
        expect(Fastlane::Helper::RevenuecatInternalHelper).not_to have_received(:insert_old_version_changelog_in_current_branch)
        expect(Fastlane::Helper::RevenuecatInternalHelper).not_to have_received(:create_pr).with('Changelog update for 10.2.1', any_args)
        expect(Fastlane::UI).to have_received(:success).with(include("Then delete `hotfix/10.2.0`. RELEASING.md"))
      end
    end

    it 'patches the latest release of a major when given only the major' do
      allow(File).to receive(:read).with('./.version').and_return("10.3.0\n")

      expect(run_action(version: '10')).to eq(release_pr_url)

      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr)
        .with('Release/10.3.1', anything, repo_name, 'hotfix/10.3.0', 'release/10.3.1', github_pr_token, labels: ['pr:next_release'])
    end

    context 'when another run creates the base branch first' do
      let(:create_ref_status) { 422 }

      it 'accepts the base branch at the tagged commit' do
        expect(run_action).to eq(release_pr_url)
      end
    end

    context 'when run interactively' do
      let(:interactive) { true }

      it 'returns to the starting branch' do
        run_action

        expect(FastlaneCore::UI).to have_received(:confirm).with('Create release/10.2.1 and, if main lacks 10.2.1, a CHANGELOG.md PR into it?')
        expect(sh_calls.last).to eq(['git', 'checkout', 'main'])
      end

      it 'stops when the user does not confirm' do
        allow(FastlaneCore::UI).to receive(:confirm).and_return(false)

        expect_user_error('Cancelled')
        expect(api_calls.map { |params| params[:http_method] }).not_to include('POST')
      end
    end

    it 'refuses a dirty working tree before changing anything' do
      allow(Fastlane::Actions::EnsureGitStatusCleanAction).to receive(:run) { FastlaneCore::UI.user_error!('Git repository is dirty!') }

      expect_user_error('Git repository is dirty!')
      expect(api_calls.map { |params| params[:http_method] }).not_to include('POST')
    end

    it 'changes nothing on a dry run' do
      expect(run_action(dry_run: true)).to be_nil

      expect(Fastlane::Actions::EnsureGitStatusCleanAction).not_to have_received(:run)
      expect(api_calls.map { |params| params[:http_method] }).to all(eq('GET'))
      expect(sh_calls).not_to include(include('checkout'))
    end
  end

  describe 'validation' do
    it 'rejects a malformed version' do
      expect_user_error(/Invalid version '10.2'/, version: '10.2')
    end

    context 'when the PR is not merged' do
      let(:merged_at) { nil }

      it { expect_user_error('PR #123 is not merged.') }
    end

    context 'when the PR was merged into another branch' do
      let(:base_ref) { 'some-feature' }

      it { expect_user_error(/was merged into some-feature, not main/) }
    end

    it 'rejects a version without a release tag' do
      expect_user_error('No release tag matches 9.', version: '9')
    end

    context 'when the next patch is already released' do
      let(:tags) { ['10.2.0', '10.2.1'] }

      it { expect_user_error('10.2.1 is already released. Hotfix 10.2.1 instead of 10.2.0.') }
    end

    context 'when the tag already contains the fix' do
      let(:fix_already_in_tag) { true }

      it 'fails before changing anything' do
        expect_user_error("10.2.0 already contains #{fix_sha}, so there is nothing to hotfix.")
        expect(api_calls.map { |params| params[:http_method] }).not_to include('POST')
      end
    end

    context 'when the PR is excluded from changelogs' do
      let(:labels) { [{ 'name' => 'pr:fix' }, { 'name' => 'pr:changelog_ignore' }] }

      it { expect_user_error('PR #123 is excluded from changelogs, so there is nothing to release.') }
    end

    context 'when the base branch exists at another commit' do
      let(:remote_base_branch_sha) { 'an0th3r' }

      it { expect_user_error('hotfix/10.2.0 points at an0th3r, not at the tagged commit t4gc0mm1t.') }
    end

    context 'when the release branch has unrelated commits' do
      let(:remote_base_branch_sha) { tag_commit }
      let(:local_release_branch) { '  release/10.2.1' }
      let(:release_branch_commits) { [['Some other change', ''], ['Fix the bug (#123)', cherry_pick_trailer]] }

      it { expect_user_error(/already has commits that are not part of this hotfix: Some other change. Release or close that hotfix first/) }
    end

    context 'when the release branch is not based on the tag' do
      let(:remote_base_branch_sha) { tag_commit }
      let(:local_release_branch) { '  release/10.2.1' }
      let(:failing_commands) { [['git', 'merge-base', '--is-ancestor', '10.2.0', 'HEAD']] }

      it { expect_user_error('release/10.2.1 is not based on 10.2.0. Delete it to start over.') }
    end

    context 'when a version file does not contain the version being patched' do
      before { allow(File).to receive(:read).with('./.version').and_return("9.0.0\n") }

      it 'fails before bumping' do
        expect_user_error(/.version does not contain version 10.2.0/)
        expect(Fastlane::Helper::RevenuecatInternalHelper).not_to have_received(:replace_version_number)
      end
    end

    context 'when a version file does not exist on the tag being patched' do
      let(:files_to_update) { { './.version' => ['{x}'], './AdMob/package.json' => ['"version": "{x}"'] } }

      before do
        allow(File).to receive(:exist?).with('./AdMob/package.json').and_return(false)
        allow(FastlaneCore::UI).to receive(:important).and_call_original
      end

      it 'bumps only the files that exist' do
        run_action(files_without_prerelease_modifiers: { './AdMob/package.json' => ['{x}'] })

        expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:replace_version_number)
          .with('10.2.0', '10.2.1', { './.version' => ['{x}'] }, {}, {})
        expect(FastlaneCore::UI).to have_received(:important).with('Skipping ./AdMob/package.json: it does not exist on 10.2.0.').twice
      end
    end

    context 'when a file is listed in both version file lists' do
      let(:files_to_update) { { './.version' => ['v{x}'] } }

      it 'checks the patterns of both lists' do
        expect { run_action(files_without_prerelease_modifiers: { './.version' => ['{x}'] }) }
          .to raise_error(FastlaneCore::Interface::FastlaneError, /.version does not contain version 10.2.0/)
      end
    end
  end

  describe 'cherry-pick failures' do
    let(:failing_commands) { [['git', 'cherry-pick', '-x', fix_sha]] }
    let(:unmerged_files) { "code.txt\n" }

    it 'aborts and comments the local command in CI' do
      expect_user_error("Cherry-picking #{fix_sha} onto release/10.2.1 conflicts. See the git output above.")

      expect(sh_calls).to include(['git', 'cherry-pick', '--abort'])
      expect(comments.size).to eq(1)
      expect(comments.first).to include('`bundle exec fastlane hotfix pr:123 version:10.2.0`')
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to have_received(:create_pr)
    end

    context 'when the cherry-pick fails without conflicts' do
      let(:unmerged_files) { '' }

      it 'reports the failure instead of asking to resolve conflicts' do
        expect_user_error(/failed without conflicts, so 10.2.0 may already contain an equivalent change/)

        expect(sh_calls).to include(['git', 'cherry-pick', '--abort'])
        expect(comments.first).to include('See the CI log.')
        expect(comments.first).not_to include('resolve the conflicts')
      end
    end

    context 'when the tag has build metadata' do
      let(:tags) { ['4.2.0+17.1.0'] }

      before { allow(File).to receive(:read).with('./.version').and_return("4.2.0+17.1.0\n") }

      it 'comments a command with a version the action accepts' do
        expect { run_action(version: '4.2.0') }.to raise_error(FastlaneCore::Interface::FastlaneError)

        expect(comments.first).to include('`bundle exec fastlane hotfix pr:123 version:4.2.0`')
      end
    end

    context 'when run interactively' do
      let(:interactive) { true }

      it 'leaves the cherry-pick in progress for the user to resolve' do
        expect_user_error(/Resolve the conflicts, run `git cherry-pick --continue`, then rerun `bundle exec fastlane hotfix pr:123 version:10.2.0`/)

        expect(sh_calls).not_to include(['git', 'cherry-pick', '--abort'])
        expect(comments).to be_empty
      end
    end
  end

  describe 'resuming' do
    let(:remote_base_branch_sha) { tag_commit }
    let(:local_release_branch) { '  release/10.2.1' }

    context 'after a resolved conflict' do
      let(:release_branch_commits) { [['Fix the bug (#123)', cherry_pick_trailer]] }

      it 'skips the cherry-pick and finishes the hotfix' do
        expect(run_action).to eq(release_pr_url)

        expect(sh_calls).to include(['git', 'checkout', 'release/10.2.1'])
        expect(sh_calls).not_to include(include('pull'))
        expect(sh_calls).not_to include(['git', 'cherry-pick', '-x', fix_sha])
        expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:commit_current_changes).with('Version bump for 10.2.1')
      end
    end

    context 'when the branch exists locally and remotely' do
      let(:remote_release_branch) { "abc\trefs/heads/release/10.2.1\n" }
      let(:release_branch_commits) { [['Version bump for 10.2.1', ''], ['Fix the bug (#123)', cherry_pick_trailer]] }
      let(:open_release_prs) { [{ 'html_url' => release_pr_url }] }

      it 'fast-forwards the local branch before checking progress' do
        run_action

        checkout_index = sh_calls.index(['git', 'checkout', 'release/10.2.1'])
        expect(sh_calls[checkout_index + 1]).to eq(['git', 'pull', '--ff-only', 'origin', 'release/10.2.1'])
      end
    end

    context 'when everything already exists' do
      let(:local_release_branch) { '' }
      let(:remote_release_branch) { "abc\trefs/heads/release/10.2.1\n" }
      let(:release_branch_commits) { [['Version bump for 10.2.1', ''], ['Fix the bug (#123)', cherry_pick_trailer]] }
      let(:open_release_prs) { [{ 'html_url' => release_pr_url }] }
      let(:open_changelog_prs) { [{ 'html_url' => changelog_pr_url }] }

      it 'checks out the pushed branch and returns the open PRs without commenting again' do
        allow(Fastlane::UI).to receive(:success)

        expect(run_action).to eq(release_pr_url)

        expect(sh_calls).to include(['git', 'fetch', 'origin', 'release/10.2.1:release/10.2.1'])
        expect(Fastlane::Helper::RevenuecatInternalHelper).not_to have_received(:replace_version_number)
        expect(Fastlane::Helper::RevenuecatInternalHelper).not_to have_received(:create_pr)
        expect(sh_calls).not_to include(include('changelog/10.2.1'))
        expect(comments).to be_empty
        expect(Fastlane::UI).to have_received(:success).with(include("merge #{changelog_pr_url}"))
      end
    end
  end

  describe 'a dependency update' do
    let(:dependency_releases) { { 'purchases-ios' => '4.5.1' } }
    let(:changelog_entry) { 'iOS 4.5.0 => 4.5.1' }
    let(:update_calls) { [] }
    let(:update_dependencies) do
      lambda do |next_version|
        update_calls << next_version
        changelog_entry
      end
    end
    let(:marker) { '(hotfix dependency update: purchases-ios 4.5.1)' }

    def run_dependency_hotfix(**options)
      run_action(pr_number: nil, update_dependencies: update_dependencies, dependency_releases: dependency_releases, **options)
    end

    it 'applies the update on the release branch, bumps the version and opens the release PR without commenting' do
      expected_changelog = "## RevenueCat SDK\n### 📦 Dependency Updates\n* iOS 4.5.0 => 4.5.1"

      expect(run_dependency_hotfix).to eq(release_pr_url)

      expect(update_calls).to eq(['10.2.1'])
      expect(sh_calls).to include(['git', 'add', '--all'])
      expect(sh_calls).to include(['git', 'commit', '-m', "iOS 4.5.0 => 4.5.1\n\n#{marker}"])
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:write_changelog).with(expected_changelog, changelog_latest_path)
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr)
        .with('Release/10.2.1', "Hotfix on 10.2.0. After the deploy, merge #{changelog_pr_url}.\n\n#{expected_changelog}", repo_name, 'hotfix/10.2.0', 'release/10.2.1', github_pr_token, labels: ['pr:next_release'])
      expect(comments).to be_empty
      expect(sh_calls.index(['git', 'checkout', '-b', 'release/10.2.1', '10.2.0'])).to be < sh_calls.index { |command| command[1] == 'commit' }
      expect(sh_calls).to include(['git', 'fetch', '--force', 'origin', 'refs/tags/*:refs/tags/*', 'refs/heads/main:refs/remotes/origin/main'])
      expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:insert_old_version_changelog_in_current_branch)
        .with('10.2.1', "#{expected_changelog}\n", end_with(File.join('worktree', changelog_path)))
    end

    context 'when the changelog entry has nested lines' do
      let(:changelog_entry) { "Updates purchases-hybrid-common to 19.18.0\n  * [Android 10.31.0](https://example.com)" }

      it 'keeps them in the commit body and the changelog' do
        run_dependency_hotfix

        expect(sh_calls).to include(['git', 'commit', '-m', "Updates purchases-hybrid-common to 19.18.0\n\n  * [Android 10.31.0](https://example.com)\n\n#{marker}"])
        expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:write_changelog)
          .with("## RevenueCat SDK\n### 📦 Dependency Updates\n* #{changelog_entry}", changelog_latest_path)
      end
    end

    context 'when a dependency version has no release' do
      let(:dependency_releases) { { 'purchases-ios' => '4.5.1', 'purchases-android' => '10.31.0' } }

      it 'fails before changing anything' do
        expect { run_dependency_hotfix }.to raise_error(FastlaneCore::Interface::FastlaneError, 'purchases-android has no 10.31.0 release.')

        expect(update_calls).to be_empty
        expect(api_calls.map { |params| params[:http_method] }).not_to include('POST')
      end
    end

    context 'when the update returns no changelog entry' do
      let(:changelog_entry) { nil }

      it { expect { run_dependency_hotfix }.to raise_error(FastlaneCore::Interface::FastlaneError, 'update_dependencies must return the changelog entry.') }
    end

    context 'when resuming with the releases in another order' do
      let(:published_dependency_releases) { ['purchases-ios/4.5.1', 'purchases-android/10.31.0'] }
      let(:dependency_releases) { { 'purchases-ios' => '4.5.1', 'purchases-android' => '10.31.0' } }
      let(:remote_base_branch_sha) { tag_commit }
      let(:local_release_branch) { '  release/10.2.1' }
      let(:release_branch_commits) { [['iOS 4.5.0 => 4.5.1', '(hotfix dependency update: purchases-android 10.31.0, purchases-ios 4.5.1)']] }

      it 'recognizes the update commit' do
        run_dependency_hotfix

        expect(update_calls).to be_empty
      end
    end

    context 'when the default branch is not main' do
      let(:default_branch) { 'develop' }

      it 'reads it from the repository and opens the changelog PR into it' do
        run_dependency_hotfix

        expect(sh_calls).to include(['git', 'fetch', '--force', 'origin', 'refs/tags/*:refs/tags/*', 'refs/heads/develop:refs/remotes/origin/develop'])
        expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:create_pr)
          .with('Changelog update for 10.2.1', anything, repo_name, 'develop', 'changelog/10.2.1', github_pr_token, labels: ['pr:other', 'pr:changelog_ignore'], team_reviewers: [])
      end
    end

    context 'when the update changes no files' do
      let(:changed_files) { '' }

      it { expect { run_dependency_hotfix }.to raise_error(FastlaneCore::Interface::FastlaneError, 'update_dependencies changed no files.') }
    end

    it 'rejects both a PR and a dependency update' do
      expect { run_dependency_hotfix(pr_number: 123) }.to raise_error(FastlaneCore::Interface::FastlaneError, 'Pass either pr_number or update_dependencies.')
    end

    it 'rejects neither a PR nor a dependency update' do
      expect { run_action(pr_number: nil) }.to raise_error(FastlaneCore::Interface::FastlaneError, 'Pass either pr_number or update_dependencies.')
    end

    it 'rejects a dependency update without the releases it applies' do
      expect { run_dependency_hotfix(dependency_releases: {}) }
        .to raise_error(FastlaneCore::Interface::FastlaneError, 'Pass the dependency_releases that update_dependencies applies.')
    end

    it 'changes nothing on a dry run' do
      expect(run_dependency_hotfix(dry_run: true)).to be_nil

      expect(update_calls).to be_empty
      expect(api_calls.map { |params| params[:http_method] }).to all(eq('GET'))
    end

    context 'when resuming after the update was committed' do
      let(:remote_base_branch_sha) { tag_commit }
      let(:local_release_branch) { '  release/10.2.1' }
      let(:release_branch_commits) { [['Updates purchases-hybrid-common to 19.18.0', "  * [Android 10.31.0](https://example.com)\n\n#{marker}"]] }

      it 'rebuilds the changelog from the commit instead of updating again' do
        run_dependency_hotfix

        expect(update_calls).to be_empty
        rebuilt_changelog = "## RevenueCat SDK\n### 📦 Dependency Updates\n* Updates purchases-hybrid-common to 19.18.0\n  * [Android 10.31.0](https://example.com)"
        expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:write_changelog).with(rebuilt_changelog, changelog_latest_path)
        expect(Fastlane::Helper::RevenuecatInternalHelper).to have_received(:insert_old_version_changelog_in_current_branch)
          .with('10.2.1', "#{rebuilt_changelog}\n", anything)
      end
    end

    context 'when the release branch has an update to other versions' do
      let(:remote_base_branch_sha) { tag_commit }
      let(:local_release_branch) { '  release/10.2.1' }
      let(:release_branch_commits) { [['iOS 4.5.0 => 4.5.2', '(hotfix dependency update: purchases-ios 4.5.2)']] }

      it { expect { run_dependency_hotfix }.to raise_error(FastlaneCore::Interface::FastlaneError, /already has commits that are not part of this hotfix: iOS 4.5.0 => 4.5.2/) }
    end
  end

  describe '.next_patch_version' do
    it 'keeps build metadata' do
      expect(described_class.next_patch_version('8.10.6+13.29.0')).to eq('8.10.7+13.29.0')
    end
  end

  describe '.resolve_tag' do
    it 'ignores prereleases and picks the latest release of the major' do
      expect(described_class.resolve_tag('11', ['11.0.0', '11.1.0-beta.1', '10.9.0'])).to eq('11.0.0')
    end

    it 'matches a version tagged with build metadata' do
      expect(described_class.resolve_tag('8.10.6', ['8.10.6+13.29.0', '8.10.5+13.28.0'])).to eq('8.10.6+13.29.0')
    end
  end
end
