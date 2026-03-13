require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/github_helper'

module Fastlane
  module Actions
    class MergePrAction < Action
      def self.run(params)
        github_token = params[:github_token]
        repo_name = params[:repo_name]
        branch = params[:branch] || Actions.sh("git rev-parse --abbrev-ref HEAD").strip
        base_branch = params[:base_branch] || 'main'
        merge_method = params[:merge_method] || 'SQUASH'

        full_repo_name = "RevenueCat/#{repo_name}"

        pr_number = Helper::GitHubHelper.find_open_pr_number(
          repo_name: full_repo_name,
          branch: branch,
          base_branch: base_branch,
          api_token: github_token
        )

        Helper::GitHubHelper.merge_pr(
          repo_name: full_repo_name,
          pr_number: pr_number,
          api_token: github_token,
          merge_method: merge_method
        )

        pr_number
      end

      def self.description
        "Merges an open PR for a given branch"
      end

      def self.details
        "Finds the open pull request from the specified branch (or the current git branch) " \
          "and merges it directly via the GitHub REST API. " \
          "All required status checks must have passed for the merge to succeed."
      end

      def self.authors
        ["RevenueCat"]
      end

      def self.return_value
        "The PR number that was merged"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       env_name: "GITHUB_TOKEN",
                                       description: "GitHub API token with repo permissions",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       description: "Name of the repository (without owner, e.g. 'purchases-ios')",
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
                                       type: String,
                                       verify_block: proc do |value|
                                         valid = %w[SQUASH MERGE REBASE]
                                         UI.user_error!("Invalid merge_method '#{value}'. Must be one of: #{valid.join(', ')}") unless valid.include?(value)
                                       end)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
