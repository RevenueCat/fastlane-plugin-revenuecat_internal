require 'fastlane_core/ui/ui'
require 'fastlane/action'
require_relative 'revenuecat_internal_helper'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    # Commits and pushes the current changes to a branch and opens a PR if one doesn't
    # already exist. Designed to be invoked via `fastlane run`, so the array-shaped inputs
    # (labels, team_reviewers, commit_paths) are passed as comma-separated strings.
    class CommitAndPrHelper
      def self.commit_push_and_create_pr_if_necessary(commit_message, branch_name, title, body, repo_name, base_branch, github_pr_token, labels, team_reviewers, commit_paths)
        if Actions.sh("git", "status", "--porcelain").strip.empty?
          UI.message("No changes detected. Skipping commit, push, and PR creation.")
          return false
        end

        paths = split_by_comma(commit_paths)
        push_changes = lambda do
          if paths.empty?
            Actions.sh("git", "add", "--all", ".")
          else
            Actions.sh("git", "add", *paths)
          end
          Actions.sh("git", "commit", "-m", commit_message)
          Actions.sh("git", "push", "-u", "origin", branch_name, "--force-with-lease")
        end

        # Assume any fastlane directory is a subdirectory of the root directory.
        if File.basename(Dir.pwd) == "fastlane"
          Dir.chdir("..") { push_changes.call }
        else
          push_changes.call
        end

        RevenuecatInternalHelper.create_pr_if_necessary(
          title, body, repo_name, base_branch, branch_name, github_pr_token,
          split_by_comma(labels), split_by_comma(team_reviewers)
        )
        true
      end

      def self.split_by_comma(value)
        return [] if value.nil?

        value.split(",").map(&:strip).reject(&:empty?)
      end
    end
  end
end
