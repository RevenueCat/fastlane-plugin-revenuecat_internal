require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require_relative 'github_helper'
require_relative 'update_hybrids_versions_file_helper'
require_relative '../constants'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)
  BUMP_VALUES = {
    skip: 0,
    patch: 1,
    minor: 2,
    major: 3
  }

  BUMP_PER_LABEL = {
    major: %w[pr:breaking].to_set,
    minor: %w[pr:feat pr:minor].to_set,
    patch: %w[pr:docs pr:fix pr:perf pr:dependencies pr:phc_dependencies pr:revenuecatui].to_set,
    skip: %w[pr:build pr:ci pr:refactor pr:style pr:test pr:next_release].to_set
  }

  module Helper
    class VersioningHelper
      # This assumes all hybrids have the same format in the VERSIONS.md.
      # When doing .gsub(/[[:space:]]/, '').split('|'), the first item is "", that's why the indexes here start with 1
      LATEST_VERSION_COLUMN = 1
      IOS_VERSION_COLUMN = 2
      ANDROID_VERSION_COLUMN = 3
      PHC_VERSION_COLUMN = 4

      def self.determine_next_version_using_labels(repo_name, github_token, rate_limit_sleep, include_prereleases)
        old_version = latest_version_number(include_prereleases: include_prereleases)
        UI.important("Determining next version after #{old_version}")

        commits = Helper::GitHubHelper.get_commits_since_old_version(github_token, old_version, repo_name)

        type_of_bump = get_type_of_bump_from_commits(commits, github_token, rate_limit_sleep, repo_name)

        UI.important("Type of bump after version #{old_version} is #{type_of_bump}")

        return calculate_next_version(old_version, type_of_bump, false), type_of_bump
      end

      def self.auto_generate_changelog(repo_name, github_token, rate_limit_sleep, include_prereleases, hybrid_common_version, versions_file_path)
        base_branch = Actions.git_branch
        Actions.sh("git fetch --tags -f")
        old_version = latest_version_number(include_prereleases: include_prereleases)
        UI.important("Auto-generating changelog since #{old_version}")

        commits = Helper::GitHubHelper.get_commits_since_old_version(github_token, old_version, repo_name)

        changelog_sections = { breaking_changes: [], new_features: [], paywalls: [], fixes: [], performance: [], dependency_updates: [], other: [] }

        commits.map do |commit|
          name = commit["commit"]["author"]["name"]

          sha = commit["sha"]
          items = Helper::GitHubHelper.get_pr_resp_items_for_sha(sha, github_token, rate_limit_sleep, repo_name, base_branch)

          case items.size
          when 1
            item = items.first

            message = "#{item['title']} (##{item['number']})"
            username = item["user"]["login"]
            types_of_change = get_type_of_change_from_pr_info(item)
            next if types_of_change.include?("pr:next_release")

            section = get_section_depending_on_types_of_change(types_of_change)

            line = "* #{message} via #{name} (@#{username})"
            if types_of_change.include?("pr:phc_dependencies")
              # Append links to native releases
              line += native_releases_links(github_token, hybrid_common_version, versions_file_path)
            end
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

      def self.platform_changelogs(releases, platform)
        platform_changelogs = []
        releases.each do |release|
          platform_changelogs.push("  * [#{platform} #{release['name']}](#{release['html_url']})")
        end
        platform_changelogs
      end

      def self.calculate_next_version(current_version, type_of_bump, snapshot)
        return current_version if type_of_bump == :skip

        is_prerelease = %w(alpha beta rc).any? { |prerelease| current_version.include?(prerelease) }
        is_valid_version = current_version.match?("^[0-9]+.[0-9]+.[0-9]+((-(alpha|beta|rc).[0-9]+)|(\\+[a-zA-Z0-9.]+))?$")

        UI.user_error!("Invalid version number: #{current_version}. Expected 3 numbers separated by '.' optionally with either a prerelease modifier or build metadata") unless is_valid_version

        delimiters = %w[. - +]
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

      def self.detect_bump_type(version_name_a, version_name_b)
        if version_name_a == version_name_b
          return :none
        end

        version_a = Gem::Version.new(version_name_a)
        version_b = Gem::Version.new(version_name_b)

        version_a_number_segments = version_name_a.to_s.split('.').length
        version_b_number_segments = version_name_b.to_s.split('.').length

        if version_a_number_segments != version_b_number_segments
          UI.error("Can't detect bump type because version #{version_a} and #{version_b} have a different format")
          return :none
        end

        if version_a_number_segments != 3
          UI.error("Can't detect bump type because versions don't follow format x.y.z")
          return :none
        end

        same_major = version_a.canonical_segments[0] == version_b.canonical_segments[0]
        same_minor = version_a.canonical_segments[1] == version_b.canonical_segments[1]
        if same_major && same_minor
          :patch
        elsif same_major
          :minor
        else
          :major
        end
      end

      def self.validate_input_if_appending_phc_version?(append_phc_version_if_next_version_is_not_prerelease, hybrid_common_version)
        if append_phc_version_if_next_version_is_not_prerelease
          UI.user_error!("Cannot append a nil PHC version.") if hybrid_common_version.nil?
          UI.user_error!("Cannot append a blank PHC version.") if hybrid_common_version.strip.empty?
        end
      end

      def self.validate_new_version_if_appending_phc_version?(append_phc_version_if_next_version_is_not_prerelease, new_version_number, hybrid_common_version)
        if append_phc_version_if_next_version_is_not_prerelease && (new_version_number.include?(DELIMITER_BUILD_METADATA) && new_version_number.partition(DELIMITER_BUILD_METADATA).last != hybrid_common_version)
          UI.user_error!(
            "Asked to append PHC version (+#{hybrid_common_version}), " \
            "but the provided version (#{new_version_number}) already has metadata " \
            "(+#{new_version_number.partition(DELIMITER_BUILD_METADATA).last})."
          )
        end
      end

      def self.append_phc_version_if_necessary(append_phc_version_if_next_version_is_not_prerelease, include_prereleases, hybrid_common_version, new_version_number)
        if append_phc_version_if_next_version_is_not_prerelease && should_append_phc_version?(include_prereleases, hybrid_common_version, new_version_number)
          UI.important(
            "Appending PHC version (+#{hybrid_common_version}) to new version (#{new_version_number}), as instructed."
          )
          return "#{new_version_number}+#{hybrid_common_version}"
        end
        return new_version_number
      end

      # rubocop:disable Metrics/PerceivedComplexity
      private_class_method def self.should_append_phc_version?(include_prereleases, hybrid_common_version, new_version_number)
        if include_prereleases
          # The BumpVersionUpdateChangelogCreatePrAction's parameter is called is_prerelease.
          UI.important("Not appending PHC version, because is_prerelease is true.")
          return false
        elsif hybrid_common_version.nil?
          UI.important("Not appending PHC version, because PHC version is nil.")
          return false
        elsif hybrid_common_version.strip.empty?
          UI.important("Not appending PHC version, because PHC version is empty.")
          return false
        elsif new_version_number.nil?
          UI.important("Not appending PHC version, because new version is nil.")
          return false
        elsif new_version_number.strip.empty?
          UI.important("Not appending PHC version, because new version is empty.")
          return false
        elsif new_version_number.include?(DELIMITER_PRERELEASE)
          UI.important("Not appending PHC version, because new version is a pre-release version.")
          return false
        elsif new_version_number.include?(DELIMITER_BUILD_METADATA)
          UI.important("Not appending PHC version, because new version already contains build metadata.")
          return false
        end

        true
      end
      # rubocop:enable Metrics/PerceivedComplexity

      private_class_method def self.latest_version_number(include_prereleases: false)
        tags = Actions
               .sh("git tag", log: false)
               .strip
               .split("\n")
               .select do |tag|
                 version, metadata = tag.split(DELIMITER_BUILD_METADATA)
                 Gem::Version.correct?(version) && (metadata.nil? || is_build_metadata(metadata))
               end

        unless include_prereleases
          tags = tags.select { |tag| tag.match("^[0-9]+.[0-9]+.[0-9]+(\\+(#{PATTERN_BUILD_METADATA}))?$") }
        end

        tags.max_by do |tag|
          version, = tag.split(DELIMITER_BUILD_METADATA)
          Gem::Version.new(version)
        end
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
          when :paywalls
            title = "### RevenueCatUI"
          when :performance
            title = "### Performance Improvements"
          when :dependency_updates
            title = "### Dependency Updates"
          else
            title = "### Other Changes"
          end
          "#{title}\n#{prs.join("\n")}"
        end.join("\n")
      end

      # rubocop:disable Metrics/PerceivedComplexity
      private_class_method def self.get_section_depending_on_types_of_change(change_types)
        if change_types.any?("pr:breaking")
          :breaking_changes
        elsif change_types.any?("pr:revenuecatui")
          :paywalls
        elsif change_types.any?("pr:feat")
          :new_features
        elsif change_types.any?("pr:fix")
          :fixes
        elsif change_types.any?("pr:perf")
          :performance
        elsif change_types.any? { |type| type == "pr:dependencies" || type == "pr:phc_dependencies" }
          :dependency_updates
        else
          :other
        end
      end
      # rubocop:enable Metrics/PerceivedComplexity

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
          .map { |label_info| label_info["name"].downcase }
          .select { |label| Helper::GitHubHelper::SUPPORTED_PR_LABELS.include?(label) }
          .to_set
      end

      private_class_method def self.get_type_of_bump_from_commits(commits, github_token, rate_limit_sleep, repo_name)
        base_branch = Actions.git_branch

        type_of_bump = :skip
        commits.each do |commit|
          break if type_of_bump == :major

          sha = commit["sha"]
          items = Helper::GitHubHelper.get_pr_resp_items_for_sha(sha, github_token, rate_limit_sleep, repo_name, base_branch)

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

          type_of_bump = BUMP_VALUES.key([BUMP_VALUES[type_of_bump_for_commit], BUMP_VALUES[type_of_bump]].max)
        end
        type_of_bump
      end

      private_class_method def self.native_releases_links(github_token, phc_version, versions_file_path)
        latest_release_row = File.readlines(versions_file_path)[2]
        if latest_release_row.nil?
          UI.error("Can't detect iOS and Android version for version #{phc_version} of purchases-hybrid-common. Empty VERSIONS.md")
          return ""
        end

        versions_latest_release = latest_release_row.gsub(/[[:space:]]/, '').split('|')
        if versions_latest_release.count < 5
          UI.error("Can't detect iOS and Android version for version #{phc_version} of purchases-hybrid-common. Malformed VERSIONS.md")
          return ""
        end

        previous_ios_version = versions_latest_release[IOS_VERSION_COLUMN]
        unless Gem::Version.correct?(previous_ios_version)
          UI.error("Malformed iOS version #{previous_ios_version} for version #{phc_version} of purchases-hybrid-common.")
          return ""
        end

        previous_android_version = versions_latest_release[ANDROID_VERSION_COLUMN]
        unless Gem::Version.correct?(previous_android_version)
          UI.error("Malformed Android version #{previous_android_version} for version #{phc_version} of purchases-hybrid-common.")
          return ""
        end

        new_android_version = Helper::UpdateHybridsVersionsFileHelper.get_android_version_for_hybrid_common_version(phc_version)
        UI.message("Obtained android version #{new_android_version} for PHC version #{phc_version}")
        new_ios_version = Helper::UpdateHybridsVersionsFileHelper.get_ios_version_for_hybrid_common_version(phc_version)
        UI.message("Obtained ios version #{new_ios_version} for PHC version #{phc_version}")

        android_releases = Helper::GitHubHelper.get_releases_between_tags(github_token, previous_android_version, new_android_version, REPO_NAME_ANDROID)
        ios_releases = Helper::GitHubHelper.get_releases_between_tags(github_token, previous_ios_version, new_ios_version, REPO_NAME_IOS)

        native_dependency_changelogs = [""]
        native_dependency_changelogs += platform_changelogs(android_releases, 'Android')
        native_dependency_changelogs += platform_changelogs(ios_releases, 'iOS')
        native_dependency_changelogs.join("\n")
      end

      private_class_method def self.is_build_metadata(string)
        !!(string =~ PATTERN_BUILD_METADATA_ANCHORED)
      end
    end
  end
end
