require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class InsertChangelogOfOlderVersionAction < Action
      def self.run(params)
        sdk_version = params[:sdk_version]
        changelog_path = params[:changelog_path]
        changelog_latest_path = params[:changelog_latest_path]
        repo_name = params[:repo_name]
        base_branch = params[:base_branch]
        github_pr_token = params[:github_pr_token]
        hybrid_common_version = params[:hybrid_common_version]
        append_phc_version = params[:append_phc_version]
        dry_run = params[:dry_run]

        if Helper::RevenuecatInternalHelper.older_than_latest_published_version?(sdk_version)
          UI.important("Version #{sdk_version} is older than the latest published version. Proceeding with changelog insertion into #{base_branch}.")

          current_branch = Actions.git_branch

          changelog_content = File.read(changelog_latest_path)

          if dry_run
            UI.important("Dry run mode enabled. No changes will be made.")
          end

          if Helper::RevenuecatInternalHelper.is_git_repo_dirty
            UI.user_error!("Your working directory has uncommitted changes. Please commit or stash them before running this action.")
          end

          Helper::RevenuecatInternalHelper.create_or_checkout_branch(base_branch)

          changelog_update_branch_name = "changelog/#{sdk_version}"

          unless dry_run
            Helper::RevenuecatInternalHelper.create_new_branch_and_checkout(changelog_update_branch_name)
          end

          final_version_number = Helper::VersioningHelper.append_phc_version_if_necessary(
            append_phc_version,
            false,
            hybrid_common_version,
            sdk_version
          )

          Helper::RevenuecatInternalHelper.insert_old_version_changelog_in_main(final_version_number, changelog_content, changelog_path)

          if dry_run
            updated_changelog = File.read(changelog_path)
            UI.important("The updated changelog would look like this:\n#{updated_changelog}")
            Helper::RevenuecatInternalHelper.discard_changes_in_current_branch

            Helper::RevenuecatInternalHelper.create_or_checkout_branch(current_branch)
          else
            Helper::RevenuecatInternalHelper.commit_changes_and_push_current_branch("Changelog update for #{sdk_version}")

            pr_title = "Changelog update for #{sdk_version}"
            pr_body = changelog_content
            Helper::RevenuecatInternalHelper.create_pr(pr_title, pr_body, repo_name, base_branch, changelog_update_branch_name, github_pr_token, ["pr:other"])

            UI.success("Successfully created PR for changelog update of version #{sdk_version}")
          end
        else
          UI.message("Version #{sdk_version} is not older than the latest published version. Skipping changelog insertion.")
        end
      end

      def self.description
        "Inserts changelog content for an older version into the main CHANGELOG.md at the correct position"
      end

      def self.authors
        ["RevenueCat"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :sdk_version,
                                       description: "The version of the SDK just released",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :changelog_path,
                                       description: "Path to CHANGELOG.md file",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :changelog_latest_path,
                                       description: "Path to CHANGELOG.latest.md file",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       env_name: "RC_INTERNAL_REPO_NAME",
                                       description: "Name of the repo of the SDK",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :base_branch,
                                       description: "The branch you want the CHANGELOG pulled into",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_pr_token,
                                       env_name: "GITHUB_PULL_REQUEST_API_TOKEN",
                                       description: "Github token to use to create the release PR",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :hybrid_common_version,
                                       description: "Version of the hybrid common sdk to add to the CHANGELOG.md file",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :append_phc_version,
                                       description: "Whether to append the hybrid_common_version to the new version number, if that new version number is not a pre-release version",
                                       optional: true,
                                       is_string: false,
                                       default_value: nil),
          FastlaneCore::ConfigItem.new(key: :dry_run,
                                       description: "Whether to run the action in dry run mode",
                                       optional: true,
                                       is_string: false,
                                       default_value: false)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
