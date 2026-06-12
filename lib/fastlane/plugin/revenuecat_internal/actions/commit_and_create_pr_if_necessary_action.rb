require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/commit_and_pr_helper'

module Fastlane
  module Actions
    class CommitAndCreatePrIfNecessaryAction < Action
      def self.run(params)
        Helper::CommitAndPrHelper.commit_push_and_create_pr_if_necessary(
          params[:commit_message],
          params[:branch_name],
          params[:title],
          params[:body],
          params[:repo_name],
          params[:base_branch],
          params[:github_pr_token],
          params[:labels],
          params[:team_reviewers],
          params[:commit_paths]
        )
      end

      def self.description
        "Commits and pushes the current changes to a branch and opens a PR if one doesn't already exist. No-ops if there's nothing to commit."
      end

      def self.authors
        ["RevenueCat"]
      end

      def self.return_value
        "True if changes were committed and pushed, false if there was nothing to commit"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :commit_message,
                                       description: "Commit message",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :branch_name,
                                       description: "Branch to commit and push to",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :title,
                                       description: "Pull request title",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :body,
                                       description: "Pull request body",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       description: "Name of the repository without owner",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :base_branch,
                                       description: "Base branch for the pull request",
                                       optional: true,
                                       default_value: "main",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_pr_token,
                                       env_name: "GITHUB_TOKEN",
                                       description: "GitHub API token with PR creation permissions",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :labels,
                                       description: "Comma-separated labels to add to the pull request",
                                       optional: true,
                                       default_value: "",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :team_reviewers,
                                       description: "Comma-separated teams to request a review from",
                                       optional: true,
                                       default_value: "coresdk",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :commit_paths,
                                       description: "Comma-separated paths to stage relative to the repo root; if empty, stages all changes",
                                       optional: true,
                                       default_value: "",
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
