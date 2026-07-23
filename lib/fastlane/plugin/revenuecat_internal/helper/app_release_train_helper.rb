require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require 'json'
require_relative 'github_helper'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    # Release-train helpers for app repos (as opposed to SDK repos): versions are
    # derived from PR labels and GitHub releases, builds are tagged builds/<version>-<build>,
    # and releases are cut from an already-uploaded candidate build on the main branch.
    class AppReleaseTrainHelper
      # Release tags are created as "<marketing-version>-<build-number>".
      RELEASE_TAG_PATTERN = /\A(?<version>\d+\.\d+\.\d+)-(?<build>[1-9]\d*)\z/

      # Highest-versioned published GitHub release tag (incl. pre-releases, excl.
      # drafts — drafts have no git tag yet); nil if there are none. The releases API
      # orders by creation date, so pick the max by version-then-build to keep a
      # late-created hotfix of an older version from becoming the baseline. API
      # failures raise: quietly treating them as "first release" would compute the
      # version from full history.
      # rubocop:disable Metrics/PerceivedComplexity
      def self.last_release_tag(repo_name, github_token)
        response = Helper::GitHubHelper.github_api_call_with_retry(
          server_url: 'https://api.github.com',
          path: "/repos/RevenueCat/#{repo_name}/releases?per_page=100",
          http_method: 'GET',
          body: {},
          api_token: github_token
        )
        releases = JSON.parse(response[:body])
        published = releases.kind_of?(Array) ? releases.reject { |release| release["draft"] } : []
        return nil if published.empty?

        tags = published.map { |release| release["tag_name"] }
        well_formed = tags.select { |tag| tag.to_s.match?(RELEASE_TAG_PATTERN) }
        # No well-formed tags: return the newest so the caller's format check reports it.
        return tags.first if well_formed.empty?

        well_formed.max_by do |tag|
          match = tag.match(RELEASE_TAG_PATTERN)
          [Gem::Version.new(match[:version]), match[:build].to_i]
        end
      rescue StandardError => e
        UI.user_error!("Could not fetch the latest GitHub release: #{e.message}")
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.release_version_from_tag(tag)
        match = tag.to_s.match(RELEASE_TAG_PATTERN)
        return match[:version] if match

        UI.user_error!("Latest GitHub release tag #{tag.inspect} does not match the expected <version>-<build> format, e.g. 1.2.3-456.")
      end

      # Returns :major / :minor / :patch / nil from the labels of PRs merged since `tag`.
      # rubocop:disable Metrics/PerceivedComplexity
      def self.bump_type_since(tag, repo_name, github_token, major_bump_labels:, minor_bump_labels:, patch_bump_labels:, changelog_ignore_label:)
        ensure_full_git_history
        Actions.sh("git", "fetch", "--tags", "--force", log: false)
        if tag && !tag_exists?(tag)
          UI.user_error!("GitHub release tag #{tag.inspect} does not exist as a git tag; was it deleted or renamed?")
        end
        range = tag ? "#{tag}..HEAD" : "HEAD"
        subjects = Actions.sh("git", "log", range, "--pretty=format:%s", log: false).split("\n")
        pr_numbers = subjects.map { |subject| pr_number_from_subject(subject) }.compact.uniq
        # The changelog-ignore label excludes the whole PR from version calculation.
        labels = pr_numbers.map { |pr_number| pr_labels_for(pr_number, repo_name, github_token, strict: true) }
                           .reject { |pr_labels| pr_labels.include?(changelog_ignore_label) }
                           .flatten.uniq

        return :major if (labels & major_bump_labels).any?
        return :minor if (labels & minor_bump_labels).any?
        return :patch if (labels & patch_bump_labels).any?

        nil
      end
      # rubocop:enable Metrics/PerceivedComplexity

      def self.calculate_next_version(current_version, bump)
        major, minor, patch = current_version.split(".").map(&:to_i)
        case bump
        when :major then "#{major + 1}.0.0"
        when :minor then "#{major}.#{minor + 1}.0"
        when :patch then "#{major}.#{minor}.#{patch + 1}"
        else UI.user_error!("Unknown bump type: #{bump}")
        end
      end

      # Next version from PR labels merged since the last release. Uses the latest
      # GitHub release tag so release history, not build artifacts, determines the
      # version range.
      def self.next_release_version(repo_name, github_token, current_version, major_bump_labels:, minor_bump_labels:, patch_bump_labels:, changelog_ignore_label:)
        last_tag = last_release_tag(repo_name, github_token)
        released_version = last_tag ? release_version_from_tag(last_tag) : current_version
        if released_version.to_s.strip.empty?
          UI.user_error!("There are no published GitHub releases and no current_version was provided to bump from.")
        end
        bump = bump_type_since(last_tag, repo_name, github_token,
                               major_bump_labels: major_bump_labels,
                               minor_bump_labels: minor_bump_labels,
                               patch_bump_labels: patch_bump_labels,
                               changelog_ignore_label: changelog_ignore_label)

        if bump.nil?
          all_bump_labels = (major_bump_labels + minor_bump_labels + patch_bump_labels).join(' / ')
          UI.user_error!("No version-bumping PR labels found since #{last_tag || 'the start of history'}. " \
                         "Nothing to release (label PRs with #{all_bump_labels}).")
        end

        # Bump from the last released version. Trunk may still show the previous
        # checked-in version until a release PR lands.
        next_version = calculate_next_version(released_version, bump)
        UI.message("Version bump: #{bump} (last released #{released_version} → #{next_version})")
        next_version
      end

      # The same GitHub-release source next_release_version derives from, so main
      # builds and cuts can never disagree on the baseline. It also covers the
      # window between finalizing a release and the release PR's merge, when the
      # checked-in version still lags the shipped one.
      def self.released_version_baseline(checked_in_version, repo_name, github_token)
        tag = begin
          last_release_tag(repo_name, github_token)
        rescue StandardError => e
          UI.important("Could not read GitHub releases (#{e.message}); baseline falls back to the checked-in version.")
          nil
        end
        released = tag && tag.match(RELEASE_TAG_PATTERN) && release_version_from_tag(tag)
        return checked_in_version unless released

        [checked_in_version, released].max_by { |version| Gem::Version.new(version) }
      end

      # Derivation starts from the last GitHub release tag (next_release_version).
      # Guards and fallbacks use released_version_baseline and must bump above it:
      # app stores reject uploads for an already-released version.
      def self.derived_version(checked_in_version, main_branch, repo_name, github_token, major_bump_labels:, minor_bump_labels:, patch_bump_labels:, changelog_ignore_label:)
        unless Actions.git_branch == main_branch
          UI.message("Using the checked-in version #{checked_in_version} (not on #{main_branch})")
          return checked_in_version
        end

        baseline = released_version_baseline(checked_in_version, repo_name, github_token)

        begin
          derived = next_release_version(repo_name, github_token, checked_in_version,
                                         major_bump_labels: major_bump_labels,
                                         minor_bump_labels: minor_bump_labels,
                                         patch_bump_labels: patch_bump_labels,
                                         changelog_ignore_label: changelog_ignore_label)
        rescue StandardError => e
          fallback = calculate_next_version(baseline, :patch)
          UI.important("Could not derive the next version from PR labels (#{e.message}); using #{fallback} (baseline #{baseline} + patch).")
          return fallback
        end

        unless Gem::Version.new(derived) > Gem::Version.new(baseline)
          fallback = calculate_next_version(baseline, :patch)
          UI.important("Derived version #{derived} is not above the released baseline #{baseline}; using #{fallback}.")
          return fallback
        end

        UI.message("Derived version #{derived} from PR labels (released baseline #{baseline})")
        derived
      end

      # Build numbers are the commit count: monotonic, collision-free across
      # concurrent merges (each merge commit has a distinct count), no network call,
      # and derivable from any checkout. Nothing is committed back to the repo.
      def self.commit_count_build_number
        ensure_full_git_history
        count = Actions.sh("git", "rev-list", "--count", "HEAD", log: false).strip
        UI.user_error!("Could not compute the build number from the commit count (got #{count.inspect}).") unless count.match?(/\A[1-9]\d*\z/)
        count.to_i
      end

      # CI checkouts can be shallow; anything that walks history (version scans,
      # commit counts) must unshallow first or it reads a truncated log.
      def self.ensure_full_git_history
        shallow = Actions.sh("git", "rev-parse", "--is-shallow-repository", log: false).strip
        Actions.sh("git", "fetch", "--unshallow", log: false) if shallow == "true"
      end

      # Namespaced under builds/ so the x.y.z-N release-tag lookups never match it,
      # and best-effort: tagging must not fail an upload that already happened.
      def self.tag_uploaded_build(version, build)
        tag_name = "builds/#{version}-#{build}"
        Actions.sh("git", "tag", tag_name)
        Actions.sh("git", "push", "origin", "refs/tags/#{tag_name}")
        UI.message("Tagged uploaded build as #{tag_name}")
      rescue StandardError => e
        UI.important("Could not tag uploaded build #{tag_name}: #{e.message}")
      end

      def self.builds_tags_at(sha)
        Actions.sh("git", "tag", "--points-at", sha, log: false)
               .split("\n").map(&:strip).select { |tag| tag.start_with?("builds/") }
      end

      # Newest main commit with an uploaded candidate.
      #
      # With allow_unbuilt: false (per-merge uploads), an untagged commit is only
      # expected when its merged PR carries the skip label; anything else fails the
      # cut rather than being silently dropped from the release.
      # With allow_unbuilt: true (scheduled uploads), untagged commits are the
      # normal state between builds; the walk passes over them and reports how
      # many will not be in the release.
      # rubocop:disable Metrics/PerceivedComplexity
      def self.find_candidate_commit(repo_name, github_token, skip_label:, lookback:, allow_unbuilt: false)
        ensure_full_git_history
        Actions.sh("git", "fetch", "--tags", "--force", log: false)
        shas = Actions.sh("git", "rev-list", "--first-parent", "-n", lookback.to_s, "HEAD", log: false)
                      .split("\n").map(&:strip).reject(&:empty?)
        walked = 0
        shas.each do |sha|
          if builds_tags_at(sha).any?
            if walked > 0 && allow_unbuilt
              UI.important("#{walked} newer commit(s) have no candidate build yet and will not be in this release. " \
                           "To include them, trigger an upload and re-cut.")
            end
            return sha
          end

          unless allow_unbuilt
            subject = Actions.sh("git", "log", "-1", "--pretty=format:%s", sha, log: false).strip
            pr_number = pr_number_from_subject(subject)
            labels = pr_number ? pr_labels_for(pr_number, repo_name, github_token) : []
            unless labels.include?(skip_label)
              UI.user_error!("#{sha[0, 8]} (#{subject}) has no candidate build and is not #{skip_label}. " \
                             "Its upload may still be running or may have failed — wait for it or re-run the upload on it, then re-cut.")
            end
            UI.message("Walking past #{sha[0, 8]} (#{skip_label} — no candidate expected)")
          end
          walked += 1
        end
        UI.user_error!("No candidate build found in the last #{lookback} commits.")
      end
      # rubocop:enable Metrics/PerceivedComplexity

      # The commit on the main branch this release branch was cut from.
      def self.release_fork_point(main_branch)
        ensure_full_git_history
        Actions.sh("git", "fetch", "origin", main_branch, log: false)
        fork_point = Actions.sh("git", "merge-base", "HEAD", "origin/#{main_branch}", log: false).strip
        UI.user_error!("Could not determine the #{main_branch} commit this release was cut from.") if fork_point.empty?
        fork_point
      end

      # The candidate is the main branch's build of the commit the release was cut
      # from, located via its builds/<version>-<build> tag.
      def self.release_candidate_build_number(version, main_branch)
        fork_point = release_fork_point(main_branch)
        Actions.sh("git", "fetch", "--tags", "--force", log: false)
        tags = Actions.sh("git", "tag", "--points-at", fork_point, log: false).split("\n").map(&:strip)
        matches = tags.map { |tag| tag.match(%r{\Abuilds/#{Regexp.escape(version)}-([1-9]\d*)\z}) }.compact
        if matches.empty?
          UI.user_error!("No builds/#{version}-* tag points at #{fork_point[0, 8]}, the #{main_branch} commit this release was cut from. " \
                         "If that commit never uploaded (a skipped merge or a failed job), re-run the upload on it or re-cut from current #{main_branch}. " \
                         "If the build was uploaded and only the best-effort tag push failed, tag it manually: " \
                         "git tag builds/#{version}-<build> #{fork_point[0, 8]} && git push origin --tags." \
                         "#{" Tags found there: #{tags.join(', ')}." unless tags.empty?}")
        end
        matches.map { |match| match[1].to_i }.max
      end

      # The build-time derivation can drift from the cut-time one (a label edited
      # after the upload, a fallback-stamped build). Without this the mismatch
      # surfaces only after the release notes and smoke test are already done.
      def self.ensure_candidate_version_matches!(sha, version)
        versions = builds_tags_at(sha)
                   .map { |tag| tag.match(%r{\Abuilds/(\d+\.\d+\.\d+)-[1-9]\d*\z})&.captures&.first }
                   .compact.uniq
        return if versions.include?(version)

        UI.user_error!("The candidate at #{sha[0, 8]} was uploaded as #{versions.join(', ')}, but the cut computes #{version} " \
                       "(labels changed since the upload?). Re-run the upload on that commit, then re-cut.")
      end

      # A reused release branch that predates current main would silently drop the
      # newly merged commits from the release.
      def self.ensure_release_branch_not_stale!(release_branch, cut_from)
        unless ancestor?(cut_from, "HEAD")
          UI.user_error!("The existing #{release_branch} branch was cut from an older commit and does not contain #{cut_from[0, 8]}. " \
                         "Delete the remote branch (and close its PR), then re-run the release cut.")
        end

        # Fail at cut time rather than later: merge commits are refused on release
        # branches (they move the fork point).
        merges = Actions.sh("git", "rev-list", "--merges", "#{cut_from}..HEAD", log: false).split("\n").reject(&:empty?)
        return if merges.empty?

        UI.user_error!("The existing #{release_branch} branch contains merge commits (#{merges.map { |merge| merge[0, 8] }.join(', ')}). " \
                       "Delete the remote branch (and close its PR), then re-run the release cut.")
      end

      # Release branches ship the build cut from main, so a code change here would
      # silently ship untested. Merge commits are refused because merging main in
      # moves the fork point, silently changing which binary gets submitted.
      # rubocop:disable Metrics/PerceivedComplexity
      def self.ensure_release_branch_is_metadata_only!(main_branch, allowed_path_prefixes, version_file, version_line_pattern)
        fork_point = release_fork_point(main_branch)
        merges = Actions.sh("git", "rev-list", "--merges", "#{fork_point}..HEAD", log: false).split("\n").reject(&:empty?)
        unless merges.empty?
          UI.user_error!("The release branch contains merge commits (#{merges.map { |merge| merge[0, 8] }.join(', ')}). " \
                         "Do not merge #{main_branch} into a release branch — to pick up new #{main_branch} commits, delete this branch, close its PR, and re-cut.")
        end

        changed = Actions.sh("git", "diff", "--name-only", "#{fork_point}..HEAD", log: false)
                         .split("\n").map(&:strip).reject(&:empty?)
        disallowed = changed.reject do |path|
          allowed_path_prefixes.any? { |prefix| path.start_with?(prefix) } || path == version_file
        end
        unless disallowed.empty?
          UI.user_error!("Release branches may only change release metadata; code changes require a fresh cut from #{main_branch}. " \
                         "Unexpected changes since #{fork_point[0, 8]}: #{disallowed.join(', ')}")
        end

        return unless version_file && changed.include?(version_file)

        diff_lines = Actions.sh("git", "diff", "#{fork_point}..HEAD", "--", version_file, log: false).lines
        edits = diff_lines.grep(/\A[+-][^+-]/)
        non_version_edits = edits.grep_v(Regexp.new(version_line_pattern.to_s))
        return if non_version_edits.empty?

        UI.user_error!("The release branch changes #{version_file} beyond lines matching #{version_line_pattern.inspect}; " \
                       "code or project changes require a fresh cut from #{main_branch}:\n#{non_version_edits.join}")
      end
      # rubocop:enable Metrics/PerceivedComplexity

      # Squash merges put the PR number at the end of the subject ("Title (#123)"),
      # so prefer a trailing "(#N)" and only then a "Merge pull request #N" prefix;
      # taking the first "(#N)" anywhere would match issue references in the title.
      def self.pr_number_from_subject(subject)
        trailing = subject.match(/\(#(\d+)\)\z/)
        return trailing[1] if trailing

        merge_commit = subject.match(/\AMerge pull request #(\d+)/)
        merge_commit && merge_commit[1]
      end

      # strict: false fails open (returns []) so a label lookup failure never blocks
      # an upload. Version calculation must use strict: true — silently missing
      # labels there would compute a wrong version bump.
      def self.pr_labels_for(pr_number, repo_name, github_token, strict: false)
        response = Helper::GitHubHelper.github_api_call_with_retry(
          server_url: 'https://api.github.com',
          path: "/repos/RevenueCat/#{repo_name}/pulls/#{pr_number}",
          http_method: 'GET',
          body: {},
          api_token: github_token
        )
        body = JSON.parse(response[:body])
        ((body && body["labels"]) || []).map { |label| label["name"] }
      rescue StandardError => e
        raise if strict

        UI.important("Could not fetch labels for PR ##{pr_number}: #{e.message}")
        []
      end

      private_class_method def self.tag_exists?(tag)
        Actions.sh("git", "rev-parse", "--verify", "--quiet", "refs/tags/#{tag}", log: false)
        true
      rescue StandardError
        false
      end

      private_class_method def self.ancestor?(ancestor_sha, descendant_ref)
        Actions.sh("git", "merge-base", "--is-ancestor", ancestor_sha, descendant_ref, log: false)
        true
      rescue StandardError
        false
      end
    end
  end
end
