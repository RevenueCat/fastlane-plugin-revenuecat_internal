describe Fastlane::Helper::AppReleaseTrainHelper do
  let(:repo_name) { 'mock-repo-name' }
  let(:github_token) { 'mock-github-token' }
  let(:label_options) do
    {
      major_bump_labels: ['pr:force_major'],
      minor_bump_labels: ['pr:breaking', 'pr:feat', 'pr:force_minor'],
      patch_bump_labels: ['pr:fix', 'pr:dependencies', 'pr:force_patch'],
      changelog_ignore_label: 'pr:changelog_ignore'
    }
  end

  def stub_releases_api(body)
    allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
      .with(server_url: 'https://api.github.com',
            path: "/repos/RevenueCat/#{repo_name}/releases?per_page=100",
            http_method: 'GET',
            body: {},
            api_token: github_token)
      .and_return({ body: body.to_json })
  end

  def stub_pr_api(pr_number, labels)
    allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
      .with(server_url: 'https://api.github.com',
            path: "/repos/RevenueCat/#{repo_name}/pulls/#{pr_number}",
            http_method: 'GET',
            body: {},
            api_token: github_token)
      .and_return({ body: { "labels" => labels.map { |name| { "name" => name } } }.to_json })
  end

  describe '.last_release_tag' do
    it 'returns nil when there are no releases' do
      stub_releases_api([])
      expect(described_class.last_release_tag(repo_name, github_token)).to be_nil
    end

    it 'excludes draft releases' do
      stub_releases_api([{ "tag_name" => "2.0.0-100", "draft" => true }])
      expect(described_class.last_release_tag(repo_name, github_token)).to be_nil
    end

    it 'picks the max by version then build, not by creation order' do
      stub_releases_api([
                          { "tag_name" => "1.2.4-101", "draft" => false },
                          { "tag_name" => "1.10.0-90", "draft" => false },
                          { "tag_name" => "1.10.0-95", "draft" => false }
                        ])
      expect(described_class.last_release_tag(repo_name, github_token)).to eq("1.10.0-95")
    end

    it 'ignores malformed tags when a well-formed one exists' do
      stub_releases_api([
                          { "tag_name" => "v2.0.0", "draft" => false },
                          { "tag_name" => "1.2.3-45", "draft" => false }
                        ])
      expect(described_class.last_release_tag(repo_name, github_token)).to eq("1.2.3-45")
    end

    it 'returns the newest raw tag when no tag is well-formed, so the caller can report the format error' do
      stub_releases_api([
                          { "tag_name" => "v2.0.0", "draft" => false },
                          { "tag_name" => "v1.0.0", "draft" => false }
                        ])
      expect(described_class.last_release_tag(repo_name, github_token)).to eq("v2.0.0")
    end

    it 'fails on API errors instead of treating them as the first release' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry)
        .and_raise(StandardError.new("boom"))
      expect do
        described_class.last_release_tag(repo_name, github_token)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Could not fetch the latest GitHub release: boom/)
    end
  end

  describe '.release_version_from_tag' do
    it 'extracts the version from a well-formed tag' do
      expect(described_class.release_version_from_tag("1.2.3-456")).to eq("1.2.3")
    end

    it 'fails on a malformed tag' do
      expect do
        described_class.release_version_from_tag("v1.2.3")
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /does not match the expected <version>-<build> format/)
    end

    it 'fails on a zero build number' do
      expect do
        described_class.release_version_from_tag("1.2.3-0")
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /does not match the expected <version>-<build> format/)
    end
  end

  describe '.bump_type_since' do
    let(:tag) { '1.0.0-10' }

    before do
      allow(described_class).to receive(:ensure_full_git_history)
      allow(Fastlane::Actions).to receive(:sh).with("git", "fetch", "--tags", "--force", log: false)
      allow(Fastlane::Actions).to receive(:sh)
        .with("git", "rev-parse", "--verify", "--quiet", "refs/tags/#{tag}", log: false)
        .and_return("abc123\n")
    end

    def stub_subjects(subjects)
      allow(Fastlane::Actions).to receive(:sh)
        .with("git", "log", "#{tag}..HEAD", "--pretty=format:%s", log: false)
        .and_return(subjects.join("\n"))
    end

    it 'returns :major when a merged PR has a major bump label' do
      stub_subjects(["Big change (#12)"])
      allow(described_class).to receive(:pr_labels_for).with("12", repo_name, github_token, strict: true).and_return(["pr:force_major"])
      expect(described_class.bump_type_since(tag, repo_name, github_token, **label_options)).to eq(:major)
    end

    it 'prefers major over minor and patch' do
      stub_subjects(["A (#1)", "B (#2)"])
      allow(described_class).to receive(:pr_labels_for).with("1", repo_name, github_token, strict: true).and_return(["pr:fix"])
      allow(described_class).to receive(:pr_labels_for).with("2", repo_name, github_token, strict: true).and_return(["pr:force_major"])
      expect(described_class.bump_type_since(tag, repo_name, github_token, **label_options)).to eq(:major)
    end

    it 'returns :minor for minor bump labels' do
      stub_subjects(["Feature (#3)"])
      allow(described_class).to receive(:pr_labels_for).with("3", repo_name, github_token, strict: true).and_return(["pr:feat"])
      expect(described_class.bump_type_since(tag, repo_name, github_token, **label_options)).to eq(:minor)
    end

    it 'returns :patch for patch bump labels' do
      stub_subjects(["Fix (#4)"])
      allow(described_class).to receive(:pr_labels_for).with("4", repo_name, github_token, strict: true).and_return(["pr:fix"])
      expect(described_class.bump_type_since(tag, repo_name, github_token, **label_options)).to eq(:patch)
    end

    it 'returns nil when no PR has a bump label' do
      stub_subjects(["Docs (#5)", "Chore without PR reference"])
      allow(described_class).to receive(:pr_labels_for).with("5", repo_name, github_token, strict: true).and_return(["pr:other"])
      expect(described_class.bump_type_since(tag, repo_name, github_token, **label_options)).to be_nil
    end

    it 'excludes the whole PR from version calculation when it has the changelog-ignore label' do
      stub_subjects(["Feature flagged work (#6)"])
      allow(described_class).to receive(:pr_labels_for).with("6", repo_name, github_token, strict: true).and_return(["pr:feat", "pr:changelog_ignore"])
      expect(described_class.bump_type_since(tag, repo_name, github_token, **label_options)).to be_nil
    end

    it 'reads PR numbers from "Merge pull request #N" subjects too' do
      stub_subjects(["Merge pull request #7 from RevenueCat/branch"])
      allow(described_class).to receive(:pr_labels_for).with("7", repo_name, github_token, strict: true).and_return(["pr:fix"])
      expect(described_class.bump_type_since(tag, repo_name, github_token, **label_options)).to eq(:patch)
    end

    it 'scans full history when there is no tag yet' do
      allow(Fastlane::Actions).to receive(:sh)
        .with("git", "log", "HEAD", "--pretty=format:%s", log: false)
        .and_return("Fix (#8)")
      allow(described_class).to receive(:pr_labels_for).with("8", repo_name, github_token, strict: true).and_return(["pr:fix"])
      expect(described_class.bump_type_since(nil, repo_name, github_token, **label_options)).to eq(:patch)
    end

    it 'fails when the release tag does not exist as a git tag' do
      allow(Fastlane::Actions).to receive(:sh)
        .with("git", "rev-parse", "--verify", "--quiet", "refs/tags/#{tag}", log: false)
        .and_raise(StandardError.new("exit 1"))
      expect do
        described_class.bump_type_since(tag, repo_name, github_token, **label_options)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /does not exist as a git tag/)
    end

    it 'propagates label lookup failures instead of computing a wrong bump' do
      stub_subjects(["Fix (#9)"])
      allow(described_class).to receive(:pr_labels_for).with("9", repo_name, github_token, strict: true).and_raise(StandardError.new("api down"))
      expect do
        described_class.bump_type_since(tag, repo_name, github_token, **label_options)
      end.to raise_error(StandardError, /api down/)
    end
  end

  describe '.calculate_next_version' do
    it 'bumps major' do
      expect(described_class.calculate_next_version("1.2.3", :major)).to eq("2.0.0")
    end

    it 'bumps minor' do
      expect(described_class.calculate_next_version("1.2.3", :minor)).to eq("1.3.0")
    end

    it 'bumps patch' do
      expect(described_class.calculate_next_version("1.2.3", :patch)).to eq("1.2.4")
    end

    it 'fails on an unknown bump type' do
      expect do
        described_class.calculate_next_version("1.2.3", :nope)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Unknown bump type: nope/)
    end
  end

  describe '.next_release_version' do
    it 'bumps from the last released version' do
      allow(described_class).to receive(:last_release_tag).with(repo_name, github_token).and_return("1.2.3-45")
      allow(described_class).to receive(:bump_type_since).with("1.2.3-45", repo_name, github_token, **label_options).and_return(:minor)
      expect(described_class.next_release_version(repo_name, github_token, "1.2.0", **label_options)).to eq("1.3.0")
    end

    it 'bootstraps from the current version when there are no releases yet' do
      allow(described_class).to receive(:last_release_tag).with(repo_name, github_token).and_return(nil)
      allow(described_class).to receive(:bump_type_since).with(nil, repo_name, github_token, **label_options).and_return(:patch)
      expect(described_class.next_release_version(repo_name, github_token, "0.9.0", **label_options)).to eq("0.9.1")
    end

    it 'fails when there are no releases and no current version to bump from' do
      allow(described_class).to receive(:last_release_tag).with(repo_name, github_token).and_return(nil)
      expect do
        described_class.next_release_version(repo_name, github_token, nil, **label_options)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /no current_version was provided/)
    end

    it 'fails when no version-bumping labels were found' do
      allow(described_class).to receive(:last_release_tag).with(repo_name, github_token).and_return("1.2.3-45")
      allow(described_class).to receive(:bump_type_since).and_return(nil)
      expect do
        described_class.next_release_version(repo_name, github_token, "1.2.0", **label_options)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /No version-bumping PR labels found since 1\.2\.3-45/)
    end

    it 'fails on a malformed latest release tag' do
      allow(described_class).to receive(:last_release_tag).with(repo_name, github_token).and_return("v1.2.3")
      expect do
        described_class.next_release_version(repo_name, github_token, "1.2.0", **label_options)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /does not match the expected <version>-<build> format/)
    end
  end

  describe '.released_version_baseline' do
    it 'falls back to the checked-in version when the releases API fails' do
      allow(described_class).to receive(:last_release_tag).and_raise(StandardError.new("api down"))
      expect(FastlaneCore::UI).to receive(:important).with(/baseline falls back to the checked-in version/)
      expect(described_class.released_version_baseline("1.2.0", repo_name, github_token)).to eq("1.2.0")
    end

    it 'uses the released version when it is above the checked-in one' do
      allow(described_class).to receive(:last_release_tag).and_return("1.3.0-50")
      expect(described_class.released_version_baseline("1.2.0", repo_name, github_token)).to eq("1.3.0")
    end

    it 'uses the checked-in version when it is above the released one' do
      allow(described_class).to receive(:last_release_tag).and_return("1.3.0-50")
      expect(described_class.released_version_baseline("1.10.0", repo_name, github_token)).to eq("1.10.0")
    end

    it 'ignores a malformed release tag' do
      allow(described_class).to receive(:last_release_tag).and_return("v9.9.9")
      expect(described_class.released_version_baseline("1.2.0", repo_name, github_token)).to eq("1.2.0")
    end

    it 'uses the checked-in version when there are no releases' do
      allow(described_class).to receive(:last_release_tag).and_return(nil)
      expect(described_class.released_version_baseline("1.2.0", repo_name, github_token)).to eq("1.2.0")
    end
  end

  describe '.derived_version' do
    def derived_version(checked_in_version)
      described_class.derived_version(checked_in_version, "main", repo_name, github_token, **label_options)
    end

    it 'returns the checked-in version off the main branch' do
      allow(Fastlane::Actions).to receive(:git_branch).and_return("feature/thing")
      expect(derived_version("1.2.0")).to eq("1.2.0")
    end

    context 'on the main branch' do
      before do
        allow(Fastlane::Actions).to receive(:git_branch).and_return("main")
        allow(described_class).to receive(:released_version_baseline).with("1.2.0", repo_name, github_token).and_return("1.2.3")
      end

      it 'returns the version derived from PR labels when above the baseline' do
        allow(described_class).to receive(:next_release_version).and_return("1.3.0")
        expect(derived_version("1.2.0")).to eq("1.3.0")
      end

      it 'falls back to a patch bump of the baseline when derivation fails' do
        allow(described_class).to receive(:next_release_version).and_raise(StandardError.new("api down"))
        expect(FastlaneCore::UI).to receive(:important).with(/Could not derive the next version from PR labels \(api down\); using 1\.2\.4 \(baseline 1\.2\.3 \+ patch\)/)
        expect(derived_version("1.2.0")).to eq("1.2.4")
      end

      it 'never returns a version at or below the released baseline' do
        allow(described_class).to receive(:next_release_version).and_return("1.2.3")
        expect(FastlaneCore::UI).to receive(:important).with(/not above the released baseline 1\.2\.3; using 1\.2\.4/)
        expect(derived_version("1.2.0")).to eq("1.2.4")
      end

      it 'falls back when the derived version is below the baseline' do
        allow(described_class).to receive(:next_release_version).and_return("1.1.0")
        expect(derived_version("1.2.0")).to eq("1.2.4")
      end
    end
  end

  describe '.commit_count_build_number' do
    before do
      allow(described_class).to receive(:ensure_full_git_history)
    end

    it 'returns the commit count as an integer' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "rev-list", "--count", "HEAD", log: false).and_return("1234\n")
      expect(described_class.commit_count_build_number).to eq(1234)
    end

    it 'fails on non-numeric output' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "rev-list", "--count", "HEAD", log: false).and_return("fatal: bad revision")
      expect do
        described_class.commit_count_build_number
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Could not compute the build number/)
    end

    it 'fails on a zero count' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "rev-list", "--count", "HEAD", log: false).and_return("0")
      expect do
        described_class.commit_count_build_number
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Could not compute the build number/)
    end
  end

  describe '.ensure_full_git_history' do
    it 'unshallows a shallow checkout' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "rev-parse", "--is-shallow-repository", log: false).and_return("true\n")
      expect(Fastlane::Actions).to receive(:sh).with("git", "fetch", "--unshallow", log: false).once
      described_class.ensure_full_git_history
    end

    it 'does nothing on a full checkout' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "rev-parse", "--is-shallow-repository", log: false).and_return("false\n")
      expect(Fastlane::Actions).not_to receive(:sh).with("git", "fetch", "--unshallow", log: false)
      described_class.ensure_full_git_history
    end
  end

  describe '.tag_uploaded_build' do
    it 'creates and pushes a builds/ tag' do
      expect(Fastlane::Actions).to receive(:sh).with("git", "tag", "builds/1.2.3-456").once
      expect(Fastlane::Actions).to receive(:sh).with("git", "push", "origin", "refs/tags/builds/1.2.3-456").once
      described_class.tag_uploaded_build("1.2.3", 456)
    end

    it 'warns but never raises when tagging fails' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "tag", "builds/1.2.3-456").and_raise(StandardError.new("tag exists"))
      expect(FastlaneCore::UI).to receive(:important).with(%r{Could not tag uploaded build builds/1\.2\.3-456: tag exists})
      expect { described_class.tag_uploaded_build("1.2.3", 456) }.not_to raise_error
    end

    it 'warns but never raises when pushing fails' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "tag", "builds/1.2.3-456")
      allow(Fastlane::Actions).to receive(:sh).with("git", "push", "origin", "refs/tags/builds/1.2.3-456").and_raise(StandardError.new("no network"))
      expect(FastlaneCore::UI).to receive(:important).with(%r{Could not tag uploaded build builds/1\.2\.3-456: no network})
      expect { described_class.tag_uploaded_build("1.2.3", 456) }.not_to raise_error
    end
  end

  describe '.builds_tags_at' do
    it 'returns only builds/ tags pointing at the sha' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "tag", "--points-at", "abc123", log: false)
                                              .and_return("builds/1.2.3-456\n1.2.3-456\nsome-other-tag\n")
      expect(described_class.builds_tags_at("abc123")).to eq(["builds/1.2.3-456"])
    end
  end

  describe '.find_candidate_commit' do
    let(:sha_a) { 'a' * 40 }
    let(:sha_b) { 'b' * 40 }

    before do
      allow(described_class).to receive(:ensure_full_git_history)
      allow(Fastlane::Actions).to receive(:sh).with("git", "fetch", "--tags", "--force", log: false)
    end

    def stub_rev_list(shas)
      allow(Fastlane::Actions).to receive(:sh)
        .with("git", "rev-list", "--first-parent", "-n", "30", "HEAD", log: false)
        .and_return("#{shas.join("\n")}\n")
    end

    def stub_subject(sha, subject)
      allow(Fastlane::Actions).to receive(:sh).with("git", "log", "-1", "--pretty=format:%s", sha, log: false).and_return(subject)
    end

    it 'returns the newest commit with a builds/ tag' do
      stub_rev_list([sha_a])
      allow(described_class).to receive(:builds_tags_at).with(sha_a).and_return(["builds/1.2.3-456"])
      expect(described_class.find_candidate_commit(repo_name, github_token, skip_label: "upload:skip", lookback: 30)).to eq(sha_a)
    end

    it 'walks past untagged commits whose PR has the skip label' do
      stub_rev_list([sha_a, sha_b])
      allow(described_class).to receive(:builds_tags_at).with(sha_a).and_return([])
      allow(described_class).to receive(:builds_tags_at).with(sha_b).and_return(["builds/1.2.3-455"])
      stub_subject(sha_a, "CI only change (#12)")
      allow(described_class).to receive(:pr_labels_for).with("12", repo_name, github_token).and_return(["upload:skip"])
      expect(described_class.find_candidate_commit(repo_name, github_token, skip_label: "upload:skip", lookback: 30)).to eq(sha_b)
    end

    it 'fails on an untagged commit without the skip label' do
      stub_rev_list([sha_a])
      allow(described_class).to receive(:builds_tags_at).with(sha_a).and_return([])
      stub_subject(sha_a, "Feature (#13)")
      allow(described_class).to receive(:pr_labels_for).with("13", repo_name, github_token).and_return(["pr:feat"])
      expect do
        described_class.find_candidate_commit(repo_name, github_token, skip_label: "upload:skip", lookback: 30)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /has no candidate build and is not upload:skip/)
    end

    it 'fails on an untagged commit with no PR reference in its subject' do
      stub_rev_list([sha_a])
      allow(described_class).to receive(:builds_tags_at).with(sha_a).and_return([])
      stub_subject(sha_a, "Direct push without PR")
      expect do
        described_class.find_candidate_commit(repo_name, github_token, skip_label: "upload:skip", lookback: 30)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /has no candidate build/)
    end

    it 'fails when no candidate exists within the lookback window' do
      stub_rev_list([sha_a, sha_b])
      allow(described_class).to receive(:builds_tags_at).and_return([])
      stub_subject(sha_a, "Skip one (#1)")
      stub_subject(sha_b, "Skip two (#2)")
      allow(described_class).to receive(:pr_labels_for).and_return(["upload:skip"])
      expect do
        described_class.find_candidate_commit(repo_name, github_token, skip_label: "upload:skip", lookback: 30)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /No candidate build found in the last 30 commits/)
    end

    context 'with allow_unbuilt: true' do
      it 'walks past untagged commits without fetching labels and warns how many were skipped' do
        stub_rev_list([sha_a, sha_b])
        allow(described_class).to receive(:builds_tags_at).with(sha_a).and_return([])
        allow(described_class).to receive(:builds_tags_at).with(sha_b).and_return(["builds/1.2.3-455"])
        expect(described_class).not_to receive(:pr_labels_for)
        expect(FastlaneCore::UI).to receive(:important).with(/1 newer commit\(s\) have no candidate build/)
        result = described_class.find_candidate_commit(repo_name, github_token, skip_label: "upload:skip", lookback: 30, allow_unbuilt: true)
        expect(result).to eq(sha_b)
      end

      it 'does not warn when the newest commit has a candidate' do
        stub_rev_list([sha_a])
        allow(described_class).to receive(:builds_tags_at).with(sha_a).and_return(["builds/1.2.3-456"])
        expect(FastlaneCore::UI).not_to receive(:important)
        result = described_class.find_candidate_commit(repo_name, github_token, skip_label: "upload:skip", lookback: 30, allow_unbuilt: true)
        expect(result).to eq(sha_a)
      end

      it 'fails when no candidate exists within the lookback window' do
        stub_rev_list([sha_a, sha_b])
        allow(described_class).to receive(:builds_tags_at).and_return([])
        expect do
          described_class.find_candidate_commit(repo_name, github_token, skip_label: "upload:skip", lookback: 30, allow_unbuilt: true)
        end.to raise_error(FastlaneCore::Interface::FastlaneError, /No candidate build found in the last 30 commits/)
      end
    end
  end

  describe '.release_fork_point' do
    before do
      allow(described_class).to receive(:ensure_full_git_history)
      allow(Fastlane::Actions).to receive(:sh).with("git", "fetch", "origin", "main", log: false)
    end

    it 'returns the merge-base with the main branch' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "merge-base", "HEAD", "origin/main", log: false).and_return("abc123\n")
      expect(described_class.release_fork_point("main")).to eq("abc123")
    end

    it 'fails when the merge-base cannot be determined' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "merge-base", "HEAD", "origin/main", log: false).and_return("")
      expect do
        described_class.release_fork_point("main")
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Could not determine the main commit this release was cut from/)
    end
  end

  describe '.release_candidate_build_number' do
    let(:fork_point) { 'f' * 40 }

    before do
      allow(described_class).to receive(:release_fork_point).with("main").and_return(fork_point)
      allow(Fastlane::Actions).to receive(:sh).with("git", "fetch", "--tags", "--force", log: false)
    end

    def stub_tags_at_fork_point(tags)
      allow(Fastlane::Actions).to receive(:sh).with("git", "tag", "--points-at", fork_point, log: false).and_return(tags.join("\n"))
    end

    it 'returns the build number of the candidate tag' do
      stub_tags_at_fork_point(["builds/1.2.3-456"])
      expect(described_class.release_candidate_build_number("1.2.3", "main")).to eq(456)
    end

    it 'returns the max build number when multiple candidate tags exist' do
      stub_tags_at_fork_point(["builds/1.2.3-456", "builds/1.2.3-457"])
      expect(described_class.release_candidate_build_number("1.2.3", "main")).to eq(457)
    end

    it 'ignores tags for other versions' do
      stub_tags_at_fork_point(["builds/1.2.4-456"])
      expect do
        described_class.release_candidate_build_number("1.2.3", "main")
      end.to raise_error(FastlaneCore::Interface::FastlaneError, %r{No builds/1\.2\.3-\* tag points at ffffffff.*Tags found there: builds/1\.2\.4-456\.}m)
    end

    it 'fails with recovery hints when the commit has no tags at all' do
      stub_tags_at_fork_point([])
      expect do
        described_class.release_candidate_build_number("1.2.3", "main")
      end.to raise_error(FastlaneCore::Interface::FastlaneError, %r{tag it manually: git tag builds/1\.2\.3-<build> ffffffff}) do |error|
        expect(error.message).not_to include("Tags found there")
      end
    end
  end

  describe '.ensure_candidate_version_matches!' do
    let(:sha) { 'c' * 40 }

    it 'passes when a candidate tag matches the computed version' do
      allow(described_class).to receive(:builds_tags_at).with(sha).and_return(["builds/1.2.3-456"])
      expect { described_class.ensure_candidate_version_matches!(sha, "1.2.3") }.not_to raise_error
    end

    it 'fails when the uploaded version differs from the computed one' do
      allow(described_class).to receive(:builds_tags_at).with(sha).and_return(["builds/1.2.3-456"])
      expect do
        described_class.ensure_candidate_version_matches!(sha, "1.3.0")
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /was uploaded as 1\.2\.3, but the cut computes 1\.3\.0/)
    end
  end

  describe '.ensure_release_branch_not_stale!' do
    let(:cut_from) { 'd' * 40 }

    it 'passes when the branch contains the cut commit and has no merge commits' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "merge-base", "--is-ancestor", cut_from, "HEAD", log: false)
      allow(Fastlane::Actions).to receive(:sh).with("git", "rev-list", "--merges", "#{cut_from}..HEAD", log: false).and_return("")
      expect { described_class.ensure_release_branch_not_stale!("release/1.2.3", cut_from) }.not_to raise_error
    end

    it 'fails when the branch does not contain the cut commit' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "merge-base", "--is-ancestor", cut_from, "HEAD", log: false)
                                              .and_raise(StandardError.new("exit 1"))
      expect do
        described_class.ensure_release_branch_not_stale!("release/1.2.3", cut_from)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, %r{release/1\.2\.3 branch was cut from an older commit and does not contain dddddddd})
    end

    it 'fails when the branch contains merge commits' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "merge-base", "--is-ancestor", cut_from, "HEAD", log: false)
      allow(Fastlane::Actions).to receive(:sh).with("git", "rev-list", "--merges", "#{cut_from}..HEAD", log: false).and_return("#{'e' * 40}\n")
      expect do
        described_class.ensure_release_branch_not_stale!("release/1.2.3", cut_from)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /contains merge commits \(eeeeeeee\)/)
    end
  end

  describe '.ensure_release_branch_is_metadata_only!' do
    let(:fork_point) { 'f' * 40 }
    let(:allowed_prefixes) { ["fastlane/metadata/"] }
    let(:version_file) { "App.xcodeproj/project.pbxproj" }
    let(:version_line_pattern) { "MARKETING_VERSION" }

    before do
      allow(described_class).to receive(:release_fork_point).with("main").and_return(fork_point)
      allow(Fastlane::Actions).to receive(:sh).with("git", "rev-list", "--merges", "#{fork_point}..HEAD", log: false).and_return("")
    end

    def stub_changed_files(paths)
      allow(Fastlane::Actions).to receive(:sh).with("git", "diff", "--name-only", "#{fork_point}..HEAD", log: false).and_return(paths.join("\n"))
    end

    def run_check
      described_class.ensure_release_branch_is_metadata_only!("main", allowed_prefixes, version_file, version_line_pattern)
    end

    it 'passes when only metadata changed' do
      stub_changed_files(["fastlane/metadata/en-US/release_notes.txt"])
      expect { run_check }.not_to raise_error
    end

    it 'fails when the branch contains merge commits' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "rev-list", "--merges", "#{fork_point}..HEAD", log: false).and_return("#{'a' * 40}\n")
      expect { run_check }.to raise_error(FastlaneCore::Interface::FastlaneError, /contains merge commits \(aaaaaaaa\)/)
    end

    it 'fails on changes outside the allowed paths' do
      stub_changed_files(["Sources/App/Feature.swift"])
      expect { run_check }.to raise_error(FastlaneCore::Interface::FastlaneError, %r{Unexpected changes since ffffffff: Sources/App/Feature\.swift})
    end

    it 'allows version file edits that only touch version lines' do
      stub_changed_files([version_file])
      diff = <<~DIFF
        --- a/App.xcodeproj/project.pbxproj
        +++ b/App.xcodeproj/project.pbxproj
        -\t\t\t\tMARKETING_VERSION = 1.2.3;
        +\t\t\t\tMARKETING_VERSION = 1.3.0;
      DIFF
      allow(Fastlane::Actions).to receive(:sh).with("git", "diff", "#{fork_point}..HEAD", "--", version_file, log: false).and_return(diff)
      expect { run_check }.not_to raise_error
    end

    it 'fails on version file edits beyond version lines' do
      stub_changed_files([version_file])
      diff = <<~DIFF
        -\t\t\t\tMARKETING_VERSION = 1.2.3;
        +\t\t\t\tMARKETING_VERSION = 1.3.0;
        +\t\t\t\tSWIFT_VERSION = 6.0;
      DIFF
      allow(Fastlane::Actions).to receive(:sh).with("git", "diff", "#{fork_point}..HEAD", "--", version_file, log: false).and_return(diff)
      expect { run_check }.to raise_error(FastlaneCore::Interface::FastlaneError, /beyond lines matching "MARKETING_VERSION"/)
    end

    it 'treats the version file as disallowed when no version file is configured' do
      stub_changed_files(["App.xcodeproj/project.pbxproj"])
      expect do
        described_class.ensure_release_branch_is_metadata_only!("main", allowed_prefixes, nil, nil)
      end.to raise_error(FastlaneCore::Interface::FastlaneError, /Unexpected changes/)
    end
  end

  describe '.pr_number_from_subject' do
    it 'prefers a trailing (#N)' do
      expect(described_class.pr_number_from_subject("Fix crash (#123)")).to eq("123")
    end

    it 'ignores issue references that are not trailing' do
      expect(described_class.pr_number_from_subject("Fix crash (#123) properly")).to be_nil
    end

    it 'reads merge commit subjects' do
      expect(described_class.pr_number_from_subject("Merge pull request #45 from RevenueCat/branch")).to eq("45")
    end

    it 'returns nil for subjects without a PR reference' do
      expect(described_class.pr_number_from_subject("Direct commit")).to be_nil
    end
  end

  describe '.pr_labels_for' do
    it 'returns the label names' do
      stub_pr_api(12, ["pr:fix", "upload:skip"])
      expect(described_class.pr_labels_for(12, repo_name, github_token)).to eq(["pr:fix", "upload:skip"])
    end

    it 'fails open with an empty list by default' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry).and_raise(StandardError.new("api down"))
      expect(FastlaneCore::UI).to receive(:important).with(/Could not fetch labels for PR #12: api down/)
      expect(described_class.pr_labels_for(12, repo_name, github_token)).to eq([])
    end

    it 'raises in strict mode' do
      allow(Fastlane::Helper::GitHubHelper).to receive(:github_api_call_with_retry).and_raise(StandardError.new("api down"))
      expect do
        described_class.pr_labels_for(12, repo_name, github_token, strict: true)
      end.to raise_error(StandardError, /api down/)
    end
  end
end
