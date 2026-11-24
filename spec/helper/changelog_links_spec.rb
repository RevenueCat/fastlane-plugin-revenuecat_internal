describe Fastlane::Helper::ChangelogLinks do
  let(:links) { described_class.new('purchases_internal', 'purchases', '2.0.1') }
  let(:public_sha) { 'a' * 40 }
  let(:source_sha) { 'b' * 40 }
  let(:mirrored_sha) { 'c' * 40 }
  let(:entry_class) { Fastlane::Helper::VersioningHelper::ChangelogEntry }
  let(:pull_request) { { 'number' => 13 } }
  let(:credit) { ' via Jane Doe (@jane-doe)' }
  let(:public_link) { "([`aaaaaaa`](https://github.com/RevenueCat/purchases/commit/#{public_sha}))" }
  let(:internal_link) { '([internal #13](https://github.com/RevenueCat/purchases_internal/pull/13))' }

  before do
    allow(Fastlane::Actions).to receive(:sh)
      .with('git', 'clone', '--bare', '--single-branch', '--no-tags', '--filter=tree:0', 'https://github.com/RevenueCat/purchases.git', anything, log: false)
    allow(Fastlane::Actions).to receive(:sh)
      .with('git', '-C', anything, 'log', '--format=%H%x09%(trailers:key=GitOrigin-RevId,valueonly,separator=%x2C)', log: false)
      .and_return("#{public_sha}\t#{source_sha}\n#{mirrored_sha}\t\n")
  end

  it 'links rewritten commits and puts the internal PR before nested dependency notes' do
    entry = entry_class.new('Update dependencies', '#13', "#{credit}\n  * [iOS 5.0](https://example.test/ios)", source_sha, pull_request)

    expect(links.line(entry)).to eq("* Update dependencies #{public_link}#{credit} #{internal_link}\n  * [iOS 5.0](https://example.test/ios)")
  end

  it 'uses a legacy mirrored SHA for a commit without a PR' do
    entry = entry_class.new('Fix a typo', nil, ' via Jane Doe', mirrored_sha)

    expect(links.line(entry)).to eq("* Fix a typo ([`ccccccc`](https://github.com/RevenueCat/purchases/commit/#{mirrored_sha})) via Jane Doe")
  end

  it 'moves the legacy external PR and contributor out of the title' do
    entry = entry_class.new('[EXTERNAL] Fix a typo (#42) by @contributor', '#13', credit, source_sha, pull_request)

    expect(links.line(entry)).to eq("* [EXTERNAL] Fix a typo #{public_link} via **@contributor** ([#42](https://github.com/RevenueCat/purchases/pull/42))#{credit} #{internal_link}")
  end

  it 'credits the original PR when the Copybara import records it in the body' do
    title = 'Fix a typo (RevenueCat/purchases#42) via @contributor'
    imported_pr = pull_request.merge('body' => 'Imports https://github.com/RevenueCat/purchases/pull/42 by @contributor at 123abc, approved by @reviewer.')
    entry = entry_class.new(title, '#13', credit, source_sha, imported_pr)

    expect(links.line(entry)).to eq("* [EXTERNAL] Fix a typo #{public_link} via **@contributor** ([#42](https://github.com/RevenueCat/purchases/pull/42))#{credit} #{internal_link}")
  end

  it 'preserves a title with a PR mention when it is not an imported contribution' do
    title = 'Follow up on a fix (RevenueCat/purchases#42) via @contributor'
    entry = entry_class.new(title, '#13', credit, source_sha, pull_request)

    expect(links.line(entry)).to eq("* #{title} #{public_link}#{credit} #{internal_link}")
  end

  it 'links to the tag for a change without an individual public commit' do
    entry = entry_class.new('Fix a typo', '#13', credit, 'd' * 40, pull_request)

    expect(links.line(entry)).to eq("* Fix a typo ([public release snapshot](https://github.com/RevenueCat/purchases/tree/2.0.1))#{credit} #{internal_link}")
  end
end
