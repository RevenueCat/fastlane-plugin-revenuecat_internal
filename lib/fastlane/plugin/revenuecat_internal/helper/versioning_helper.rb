require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require_relative 'github_helper'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class VersioningHelper
      def self.determine_next_version_using_labels(repo_name, github_token, rate_limit_sleep)
        old_version = latest_non_prerelease_version_number
        UI.important("Determining next version after #{old_version}")

        commits = Helper::GitHubHelper.get_commits_since_old_version(github_token, old_version, repo_name)

        type_of_bump = :patch

        commits.each do |commit|
          break if type_of_bump == :major

          sha = commit["sha"]
          items = Helper::GitHubHelper.get_pr_resp_items_for_sha(sha, github_token, rate_limit_sleep, repo_name)

          if items.size == 1
            item = items.first

            types_of_change = get_type_of_change_from_pr_info(item)

            type_of_bump_for_change = get_type_of_bump_from_types_of_change(types_of_change)

            type_of_bump = type_of_bump_for_change unless type_of_bump_for_change == :patch
          else
            UI.user_error!("Cannot determine next version. Multiple commits found for #{sha}")
          end
        end
        UI.important("Type of bump after version #{old_version} is #{type_of_bump}")
        increase_version(old_version, type_of_bump, false)
      end

      def self.auto_generate_changelog(repo_name, github_token, rate_limit_sleep)
        Actions.sh("git fetch --tags")
        old_version = latest_non_prerelease_version_number
        UI.important("Auto-generating changelog since #{old_version}")

        commits = Helper::GitHubHelper.get_commits_since_old_version(github_token, old_version, repo_name)

        changelog_sections = { breaking_changes: [], fixes: [], new_features: [], other: [] }

        commits.map do |commit|
          name = commit["commit"]["author"]["name"]

          sha = commit["sha"]
          items = Helper::GitHubHelper.get_pr_resp_items_for_sha(sha, github_token, rate_limit_sleep, repo_name)

          if items.size == 1
            item = items.first

            message = "#{item['title']} (##{item['number']})"
            username = item["user"]["login"]
            types_of_change = get_type_of_change_from_pr_info(item)

            section = get_section_depending_on_types_of_change(types_of_change)

            line = "* #{message} via #{name} (@#{username})"
            changelog_sections[section].push(line)
          else
            UI.user_error!("Cannot generate changelog. Multiple commits found for #{sha}")
          end
        end
        build_changelog_sections(changelog_sections)
      end

      def self.increase_version(current_version, type_of_bump, snapshot)
        version_split = current_version.split('.')
        UI.user_error("Invalid version number: #{current_version}. Expected 3 numbers separated by '.'") if version_split.size != 3

        major = version_split[0]
        minor = version_split[1]
        patch = version_split[2]

        case type_of_bump
        when :major
          next_version = "#{major.to_i + 1}.0.0"
        when :minor
          next_version = "#{major}.#{minor.to_i + 1}.0"
        else
          next_version = "#{major}.#{minor}.#{patch.to_i + 1}"
        end

        if snapshot
          "#{next_version}-SNAPSHOT"
        else
          next_version
        end
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
        if change_types.include?("breaking")
          :major
        elsif change_types.include?("feat")
          :minor
        else
          :patch
        end
      end

      private_class_method def self.get_type_of_change_from_pr_info(pr_info)
        pr_info["labels"]
          .map { |label_info| label_info["name"] }
          .select { |label| Helper::GitHubHelper::SUPPORTED_PR_LABELS.include?(label) }
          .to_set
      end
    end
  end
end