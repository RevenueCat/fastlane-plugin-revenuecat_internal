describe Fastlane::Helper::CommitAndPrHelper do
  describe '.commit_push_and_create_pr_if_necessary' do
    it 'no-ops and returns false when there are no changes' do
      allow(Fastlane::Actions).to receive(:sh).with("git", "status", "--porcelain").and_return("")
      expect(Fastlane::Helper::RevenuecatInternalHelper).not_to receive(:create_pr_if_necessary)

      result = described_class.commit_push_and_create_pr_if_necessary(
        "msg", "branch", "title", "body", "repo", "main", "token", "", "coresdk", ""
      )

      expect(result).to be(false)
    end

    it 'stages the given paths, commits, force-pushes and opens a PR' do
      allow(Dir).to receive(:pwd).and_return("/repo")
      allow(Fastlane::Actions).to receive(:sh).with("git", "status", "--porcelain").and_return(" M generated.kt")
      expect(Fastlane::Actions).to receive(:sh).with("git", "add", "a", "b").once
      expect(Fastlane::Actions).to receive(:sh).with("git", "commit", "-m", "msg").once
      expect(Fastlane::Actions).to receive(:sh).with("git", "push", "-u", "origin", "branch", "--force-with-lease").once
      expect(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr_if_necessary).with(
        "title", "body", "repo", "main", "branch", "token", %w[pr:other auto:codegen], %w[coresdk]
      ).once

      result = described_class.commit_push_and_create_pr_if_necessary(
        "msg", "branch", "title", "body", "repo", "main", "token",
        "pr:other, auto:codegen", "coresdk", "a, b"
      )

      expect(result).to be(true)
    end

    it 'stages all changes when no commit_paths are given' do
      allow(Dir).to receive(:pwd).and_return("/repo")
      allow(Fastlane::Actions).to receive(:sh).with("git", "status", "--porcelain").and_return(" M generated.kt")
      expect(Fastlane::Actions).to receive(:sh).with("git", "add", "--all", ".").once
      allow(Fastlane::Actions).to receive(:sh).with("git", "commit", "-m", "msg")
      allow(Fastlane::Actions).to receive(:sh).with("git", "push", "-u", "origin", "branch", "--force-with-lease")
      allow(Fastlane::Helper::RevenuecatInternalHelper).to receive(:create_pr_if_necessary)

      described_class.commit_push_and_create_pr_if_necessary(
        "msg", "branch", "title", "body", "repo", "main", "token", "", "coresdk", ""
      )
    end
  end
end
