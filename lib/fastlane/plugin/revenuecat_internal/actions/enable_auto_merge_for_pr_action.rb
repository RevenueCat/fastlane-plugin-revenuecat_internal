require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/github_helper'

module Fastlane
  module Actions
    class EnableAutoMergeForPrAction < Action
      def self.run(params)
        github_token = params[:github_token]
        repo_name = params[:repo_name]
        branch = params[:branch] || Actions.sh("git rev-parse --abbrev-ref HEAD").strip
        base_branch = params[:base_branch] || 'main'
        merge_method = params[:merge_method] || 'SQUASH'

        owner = repo_name.split('/').first

        UI.message("Looking for open PR from #{branch} into #{base_branch}...")

        response = Helper::GitHubHelper.github_api_call_with_retry(
          server_url: "https://api.github.com",
          http_method: "GET",
          path: "/repos/#{repo_name}/pulls?head=#{owner}:#{branch}&base=#{base_branch}&state=open",
          api_token: github_token
        )

        prs = JSON.parse(response[:body])
        UI.user_error!("No open PR found from #{branch} into #{base_branch}") if prs.empty?

        pr_number = prs.first["number"]
        UI.message("Found PR ##{pr_number}: #{prs.first["title"]}")

        Helper::GitHubHelper.enable_auto_merge(
          repo_name: repo_name,
          pr_number: pr_number,
          api_token: github_token,
          merge_method: merge_method
        )
      end

      def self.description
        "Enables auto-merge on an open PR for a given branch"
      end

      def self.details
        "Finds the open pull request from the specified branch (or the current git branch) " \
          "and enables GitHub's auto-merge feature on it. " \
          "The repository must have 'Allow auto-merge' enabled in Settings > General."
      end

      def self.authors
        ["RevenueCat"]
      end

      def self.return_value
        nil
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       env_name: "GITHUB_TOKEN",
                                       description: "GitHub API token with repo permissions",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       description: "Full repository name with owner (e.g. 'RevenueCat/purchases-ios')",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :branch,
                                       description: "Head branch of the PR. Defaults to the current git branch",
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :base_branch,
                                       description: "Base branch the PR targets. Defaults to 'main'",
                                       optional: true,
                                       default_value: "main",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :merge_method,
                                       description: "Merge method: 'SQUASH', 'MERGE', or 'REBASE'",
                                       optional: true,
                                       default_value: "SQUASH",
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
