require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require_relative 'github_helper'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)
  BUMP_VALUES = {
    skip: 0,
    patch: 1,
    minor: 2,
    major: 3
  }

  BUMP_PER_LABEL = {
    major: %w[breaking].to_set,
    minor: %w[feat minor].to_set,
    patch: %w[docs fix perf dependencies].to_set,
    skip: %w[build ci refactor style test next_release].to_set
  }

  module Helper
    class VersioningHelper
      def self.determine_next_version_using_labels(repo_name, github_token, rate_limit_sleep)
        old_version = latest_non_prerelease_version_number
        UI.important("Determining next version after #{old_version}")

        commits = Helper::GitHubHelper.get_commits_since_old_version(github_token, old_version, repo_name)

        type_of_bump = get_type_of_bump_from_commits(commits, github_token, rate_limit_sleep, repo_name, type_of_bump)

        UI.important("Type of bump after version #{old_version} is #{type_of_bump}")

        return calculate_next_version(old_version, type_of_bump, false), type_of_bump
      end

      def self.auto_generate_changelog(repo_name, github_token, rate_limit_sleep)
        Actions.sh("git fetch --tags -f")
        old_version = latest_non_prerelease_version_number
        UI.important("Auto-generating changelog since #{old_version}")

        commits = Helper::GitHubHelper.get_commits_since_old_version(github_token, old_version, repo_name)

        changelog_sections = { breaking_changes: [], new_features: [], fixes: [], other: [] }

        commits.map do |commit|
          name = commit["commit"]["author"]["name"]

          sha = commit["sha"]
          items = Helper::GitHubHelper.get_pr_resp_items_for_sha(sha, github_token, rate_limit_sleep, repo_name)

          case items.size
          when 1
            item = items.first

            message = "#{item['title']} (##{item['number']})"
            username = item["user"]["login"]
            types_of_change = get_type_of_change_from_pr_info(item)
            next if types_of_change.include?("next_release")

            section = get_section_depending_on_types_of_change(types_of_change)

            line = "* #{message} via #{name} (@#{username})"
            changelog_sections[section].push(line)
          when 0
            UI.important("Cannot find pull request associated to #{sha}. Using commit information and adding it to the Other section")
            message = commit["commit"]["message"]
            name = commit["commit"]["author"]["name"]
            username = commit["author"]["login"]
            line = "* #{message} via #{name} (@#{username})"
            changelog_sections[:other].push(line)
          else
            UI.user_error!("Cannot generate changelog. Multiple commits found for #{sha}")
          end
        end
        build_changelog_sections(changelog_sections)
      end

      def self.calculate_next_version(current_version, type_of_bump, snapshot)
        return current_version if type_of_bump == :skip

        is_prerelease = %w(alpha beta rc).any? { |prerelease| current_version.include?(prerelease) }
        is_valid_version = current_version.match?("^[0-9]+.[0-9]+.[0-9]+(-(alpha|beta|rc).[0-9]+)?$")

        UI.user_error!("Invalid version number: #{current_version}. Expected 3 numbers separated by '.' with an optional prerelease modifier") unless is_valid_version

        delimiters = ['.', '-']
        version_split = current_version.split(Regexp.union(delimiters))

        major = version_split[0]
        minor = version_split[1]
        patch = version_split[2]

        if is_prerelease
          next_version = "#{major}.#{minor}.#{patch}"
        else
          case type_of_bump
          when :major
            next_version = "#{major.to_i + 1}.0.0"
          when :minor
            next_version = "#{major}.#{minor.to_i + 1}.0"
          else
            next_version = "#{major}.#{minor}.#{patch.to_i + 1}"
          end
        end

        snapshot ? "#{next_version}-SNAPSHOT" : next_version
      end

      private_class_method def self.latest_non_prerelease_version_number
        Actions
          .sh("git tag", log: false)
          .strip
          .split("\n")
          .select { |tag| tag.match("^[0-9]+.[0-9]+.[0-9]+$") }
          .max_by { |tag| Gem::Version.new(tag) }
      end

      private_class_method def self.build_changelog_sections(changelog_sections)
        changelog_sections.reject { |_, v| v.empty? }.map do |section_name, prs|
          next unless prs.size > 0

          case section_name
          when :breaking_changes
            title = "### Breaking Changes"
          when :fixes
            title = "### Bugfixes"
          when :new_features
            title = "### New Features"
          else
            title = "### Other Changes"
          end
          "#{title}\n#{prs.join("\n")}"
        end.join("\n")
      end

      private_class_method def self.get_section_depending_on_types_of_change(change_types)
        if change_types.include?("breaking")
          :breaking_changes
        elsif change_types.include?("feat")
          :new_features
        elsif change_types.include?("fix")
          :fixes
        else
          :other
        end
      end

      private_class_method def self.get_type_of_bump_from_types_of_change(change_types)
        if change_types.intersection(BUMP_PER_LABEL[:major]).size > 0
          :major
        elsif change_types.intersection(BUMP_PER_LABEL[:minor]).size > 0
          :minor
        elsif change_types.intersection(BUMP_PER_LABEL[:patch]).size > 0
          :patch
        else
          :skip
        end
      end

      private_class_method def self.get_type_of_change_from_pr_info(pr_info)
        pr_info["labels"]
          .map { |label_info| label_info["name"] }
          .select { |label| Helper::GitHubHelper::SUPPORTED_PR_LABELS.include?(label) }
          .to_set
      end

      def self.get_type_of_bump_from_commits(commits, github_token, rate_limit_sleep, repo_name, type_of_bump)]
        type_of_bump = :skip
        commits.each do |commit|
          break if type_of_bump == :major

          sha = commit["sha"]
          items = Helper::GitHubHelper.get_pr_resp_items_for_sha(sha, github_token, rate_limit_sleep, repo_name)

          if items.size == 0
            # skip this commit to minimize risk. If there are more commits, we'll use the current type_of_bump
            # if there are no more commits, we'll skip the version bump
            UI.important("There is no pull request associated with #{sha}")
            next
          elsif items.size > 1
            UI.user_error!("Cannot determine next version. Multiple commits found for #{sha}")
          end

          item = items.first
          commit_supported_labels = get_type_of_change_from_pr_info(item)
          type_of_bump_for_commit = get_type_of_bump_from_types_of_change(commit_supported_labels)

          puts("type_of_bump_for_commit #{type_of_bump_for_commit}")
          puts("type_of_bump #{type_of_bump}")

          type_of_bump = BUMP_VALUES.key([BUMP_VALUES[type_of_bump_for_commit], BUMP_VALUES[type_of_bump]].max)
        end
        type_of_bump
      end
    end
  end
end
