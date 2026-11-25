describe Fastlane::Helper::ChangelogLinks do
  let(:links) { described_class.new('purchases_internal', 'purchases') }
  let(:public_sha) { 'a' * 40 }
  let(:source_sha) { 'b' * 40 }
  let(:mirrored_sha) { 'c' * 40 }
  let(:entry_class) { Fastlane::Helper::VersioningHelper::ChangelogEntry }
  let(:pull_request) { { 'number' => 13, 'merge_commit_sha' => source_sha, 'merged_at' => '2026-11-24T12:00:00Z' } }
  let(:credit) { ' via Jane Doe (@jane-doe)' }
  let(:public_link) { "([`aaaaaaa`](https://github.com/RevenueCat/purchases/commit/#{public_sha}))" }
  let(:internal_link) { '([RevenueCat/purchases_internal#13](https://github.com/RevenueCat/purchases_internal/pull/13))' }
  let(:snapshot_link) { '([public release snapshot](https://github.com/RevenueCat/purchases/tree/refs/tags/2.0.1))' }
  let(:git_status) { instance_double(Process::Status, success?: true) }
  let(:git_history) { "#{public_sha}\t#{source_sha}\0#{mirrored_sha}\t\0" }

  before do
    allow(Open3).to receive(:capture3)
      .with(hash_including('GIT_TERMINAL_PROMPT' => '0'), 'git', '-c', 'credential.helper=', '-c', 'core.askPass=', '-c', 'http.lowSpeedLimit=1', '-c', 'http.lowSpeedTime=30',
            'clone', '--quiet', '--bare', '--single-branch', '--no-tags', '--filter=tree:0', 'https://github.com/RevenueCat/purchases.git', '.', chdir: anything, binmode: true)
      .and_return(['', '', git_status])
    allow(Open3).to receive(:capture3)
      .with(anything, 'git', 'log', '-z', '--format=%H%x09%(trailers:key=GitOrigin-RevId,valueonly,unfold,separator=%x2C)', chdir: anything, binmode: true)
      .and_return([git_history, '', git_status])
  end

  it 'links rewritten commits and puts the internal PR before nested dependency notes' do
    entry = entry_class.new('Update dependencies', '#13', credit, source_sha, pull_request, "\n  * [iOS 5.0](https://example.test/ios)")

    expect(links.line(entry)).to eq("* Update dependencies #{public_link}#{credit} #{internal_link}\n  * [iOS 5.0](https://example.test/ios)")
  end

  it 'uses a legacy mirrored SHA for a commit without a PR' do
    entry = entry_class.new('Fix a typo', nil, ' via Jane Doe', mirrored_sha)

    expect(links.line(entry)).to eq("* Fix a typo ([`ccccccc`](https://github.com/RevenueCat/purchases/commit/#{mirrored_sha})) via Jane Doe")
  end

  it 'moves the legacy external PR and contributor out of the title' do
    imported_pr = pull_request.merge('body' => "Description\n\nContributed by @contributor in https://github.com/RevenueCat/purchases/pull/42")
    entry = entry_class.new('[EXTERNAL] Fix a typo (#42) by @contributor', '#13', credit, source_sha, imported_pr)

    expect(links.line(entry)).to eq("* \\[EXTERNAL\\] Fix a typo #{public_link} via **@contributor** ([RevenueCat/purchases#42](https://github.com/RevenueCat/purchases/pull/42))#{credit} #{internal_link}")
  end

  it 'credits the original PR when the Copybara import records it in the body' do
    title = 'Fix a typo (RevenueCat/purchases#42) via @contributor'
    imported_pr = pull_request.merge('body' => 'Imports https://github.com/RevenueCat/purchases/pull/42 by @contributor at 123abc, approved by @reviewer.')
    entry = entry_class.new(title, '#13', credit, source_sha, imported_pr)

    expect(links.line(entry)).to eq("* \\[EXTERNAL\\] Fix a typo #{public_link} via **@contributor** ([RevenueCat/purchases#42](https://github.com/RevenueCat/purchases/pull/42))#{credit} #{internal_link}")
  end

  it 'preserves a title with a PR mention when it is not an imported contribution' do
    title = 'Follow up on a fix (RevenueCat/purchases#42) via @contributor'
    entry = entry_class.new(title, '#13', credit, source_sha, pull_request)

    expect(links.line(entry)).to eq("* Follow up on a fix (RevenueCat/purchases\\#42) via @contributor #{public_link}#{credit} #{internal_link}")
  end

  it 'requires the original PR attribution in the body for legacy imports' do
    entry = entry_class.new('[EXTERNAL] Fix a typo (#42) by @contributor', '#13', credit, source_sha, pull_request)

    expect(links.line(entry)).to eq("* \\[EXTERNAL\\] Fix a typo (\\#42) by @contributor #{public_link}#{credit} #{internal_link}")
  end

  it 'renders titles and authors as text while retaining the generated links' do
    title = "Fix [reference](https://example.test)\n* Update <tag>\u202e"
    entry = entry_class.new(title, '#13', " via Jane\n* Doe (@jane-doe)", source_sha, pull_request)

    expect(links.line(entry)).to eq("* Fix \\[reference\\](https://example.test) \\* Update \\<tag\\> #{public_link} via Jane \\* Doe (@jane-doe) #{internal_link}")
  end

  it 'preserves a code span and an intraword underscore in a title' do
    entry = entry_class.new('add `CheckpointResult` result_container', '#13', credit, source_sha, pull_request)

    expect(links.line(entry)).to eq("* add `CheckpointResult` result_container #{public_link}#{credit} #{internal_link}")
  end

  it 'escapes unmatched backticks before appending the commit link' do
    entry = entry_class.new('add `CheckpointResult', '#13', credit, source_sha, pull_request)

    expect(links.line(entry)).to eq("* add \\`CheckpointResult #{public_link}#{credit} #{internal_link}")
  end

  it 'warns and keeps the verified PR link when the public commit is missing' do
    missing_sha = 'd' * 40
    entry = entry_class.new('Fix a typo', '#13', credit, missing_sha, pull_request.merge('merge_commit_sha' => missing_sha))
    expect(FastlaneCore::UI).to receive(:important).with(/Source commit #{missing_sha} has no match.*without a public commit link/)

    expect(links.line(entry)).to eq("* Fix a typo#{credit} #{internal_link}")
  end

  context 'when generating a hotfix' do
    let(:links) { described_class.new('purchases_internal', 'purchases', snapshot_tag: '2.0.1') }

    it 'logs the missing match and links the release tag' do
      missing_sha = 'd' * 40
      entry = entry_class.new('Fix a typo', '#13', credit, missing_sha, pull_request.merge('merge_commit_sha' => missing_sha))
      expect(FastlaneCore::UI).to receive(:important).with(/Source commit #{'d' * 40} has no match.*Using the public release snapshot for hotfix 2\.0\.1/)

      expect(links.line(entry)).to eq("* Fix a typo #{snapshot_link}#{credit} #{internal_link}")
    end
  end

  context 'with an explicitly allowed snapshot SHA on a regular release' do
    let(:release_only_sha) { 'd' * 40 }
    let(:links) { described_class.new('purchases_internal', 'purchases', snapshot_tag: '2.0.1', snapshot_fallback_shas: [release_only_sha]) }

    it 'logs the override and links to the release snapshot for that SHA' do
      entry = entry_class.new('Fix a typo', '#13', credit, release_only_sha, pull_request.merge('merge_commit_sha' => release_only_sha))
      expect(FastlaneCore::UI).to receive(:important).with(/Source commit #{release_only_sha} has no match.*snapshot_fallback_shas/)

      expect(links.line(entry)).to eq("* Fix a typo #{snapshot_link}#{credit} #{internal_link}")
    end

    it 'omits the commit link when a different SHA is missing' do
      missing_sha = 'e' * 40
      entry = entry_class.new('Fix a typo', '#13', credit, missing_sha, pull_request.merge('merge_commit_sha' => missing_sha))

      expect(links.line(entry)).to eq("* Fix a typo#{credit} #{internal_link}")
    end
  end

  it 'requires full SHAs for the snapshot override' do
    expect { described_class.new('purchases_internal', 'purchases', snapshot_tag: '2.0.1', snapshot_fallback_shas: ['a1b2c3d']) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /snapshot_fallback_shas must contain full lowercase Git commit SHAs/)
  end

  context 'when two exports claim the same source SHA' do
    let(:git_history) { "#{public_sha}\t#{source_sha}\0#{mirrored_sha}\t#{source_sha}\0" }

    it 'warns and omits the public commit link for an ambiguous mapping' do
      entry = entry_class.new('Fix a typo', '#13', credit, source_sha, pull_request)
      expect(FastlaneCore::UI).to receive(:important).with(/Multiple commits.*claim source SHA #{source_sha}/)

      expect(links.line(entry)).to eq("* Fix a typo#{credit} #{internal_link}")
    end
  end

  context 'when a trailer references a commit that is itself public' do
    let(:git_history) { "#{public_sha}\t#{mirrored_sha}\0#{mirrored_sha}\t\0" }

    it 'uses the exact SHA' do
      entry = entry_class.new('Fix a typo', nil, ' via Jane Doe', mirrored_sha)

      expect(links.line(entry)).to include("/commit/#{mirrored_sha}")
    end
  end

  context 'when a trailer contains multiple values or a continuation' do
    let(:git_history) { "#{public_sha}\t#{source_sha},#{mirrored_sha}\0#{mirrored_sha}\tinvalid\n#{public_sha}\t#{source_sha}\0" }

    it 'ignores the invalid origin values' do
      entry = entry_class.new('Fix a typo', '#13', credit, source_sha, pull_request)

      expect(links.line(entry)).to eq("* Fix a typo#{credit} #{internal_link}")
    end
  end

  context 'when the public Git read fails' do
    let(:git_status) { instance_double(Process::Status, success?: false) }

    it 'warns once and retains entries and their verified PR links' do
      entry = entry_class.new('Fix a typo', '#13', credit, source_sha, pull_request)
      expect(FastlaneCore::UI).to receive(:important).with(%r{Could not read public commit history from .*/purchases}).once

      2.times { expect(links.line(entry)).to eq("* Fix a typo#{credit} #{internal_link}") }
    end

    context 'when generating a hotfix' do
      let(:links) { described_class.new('purchases_internal', 'purchases', snapshot_tag: '2.0.1') }

      it 'still links the release tag' do
        entry = entry_class.new('Fix a typo', '#13', credit, source_sha, pull_request)
        allow(FastlaneCore::UI).to receive(:important)

        expect(links.line(entry)).to eq("* Fix a typo #{snapshot_link}#{credit} #{internal_link}")
        expect(FastlaneCore::UI).to have_received(:important).with(/Public commit history is unavailable for source commit #{source_sha}.*hotfix 2\.0\.1/)
      end
    end

    context 'with an explicitly allowed snapshot SHA on a regular release' do
      let(:links) { described_class.new('purchases_internal', 'purchases', snapshot_tag: '2.0.1', snapshot_fallback_shas: [source_sha]) }

      it 'links the release tag only for the allowed SHA' do
        allowed = entry_class.new('Fix a typo', '#13', credit, source_sha, pull_request)
        other_sha = 'e' * 40
        other = entry_class.new('Fix another typo', '#13', credit, other_sha, pull_request.merge('merge_commit_sha' => other_sha))
        allow(FastlaneCore::UI).to receive(:important)

        expect(links.line(allowed)).to eq("* Fix a typo #{snapshot_link}#{credit} #{internal_link}")
        expect(links.line(other)).to eq("* Fix another typo#{credit} #{internal_link}")
      end
    end
  end

  it 'fails instead of dropping links when build receives an invalid snapshot SHA' do
    expect { described_class.build('purchases_internal', 'purchases', snapshot_tag: '2.0.1', snapshot_fallback_shas: ['a1b2c3d']) }
      .to raise_error(FastlaneCore::Interface::FastlaneError, /snapshot_fallback_shas must contain full lowercase Git commit SHAs/)
  end

  it 'identifies an invalid public repository name and its value' do
    expect { described_class.new('purchases_internal', '../another-repo') }
      .to raise_error(FastlaneCore::Interface::FastlaneError, 'Invalid public repository name (public_repo_name) "../another-repo". Pass a GitHub repository name without an owner.')
  end

  it 'identifies an invalid internal repository name and its value' do
    expect { described_class.new('RevenueCat/purchases_internal', 'purchases') }
      .to raise_error(FastlaneCore::Interface::FastlaneError, 'Invalid internal repository name (repo_name) "RevenueCat/purchases_internal". Pass a GitHub repository name without an owner.')
  end
end
