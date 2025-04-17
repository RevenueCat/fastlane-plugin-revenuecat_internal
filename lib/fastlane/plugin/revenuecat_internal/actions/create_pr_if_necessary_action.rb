require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class CreatePrIfNecessaryAction < Action
      def self.run(params)
        title = params[:title]
        body = params[:body]
        repo_name = params[:repo_name]
        base_branch = params[:base_branch]
        head_branch = params[:head_branch]
        github_pr_token = params[:github_pr_token]
        labels = params[:labels]
        team_reviewers = params[:team_reviewers]

        Helper::RevenuecatInternalHelper.create_pr_if_necessary(
          title,
          body,
          repo_name,
          base_branch,
          head_branch,
          github_pr_token,
          labels,
          team_reviewers
        )
      end

      def self.description
        "Creates a pull request if one doesn't already exist for the specified branch"
      end

      def self.authors
        ["Jay Shortway"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :title,
                                       description: "Title of the pull request",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :body,
                                       description: "Body content of the pull request",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       description: "Name of the repository (without owner)",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :base_branch,
                                       description: "The branch you want your changes pulled into",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :head_branch,
                                       description: "The branch where your changes are implemented",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_pr_token,
                                       description: "GitHub API token with PR creation permissions",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :labels,
                                       description: "Labels to add to the pull request",
                                       optional: true,
                                       default_value: [],
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :team_reviewers,
                                       description: "Teams to request a review from",
                                       optional: true,
                                       default_value: ['coresdk'],
                                       type: Array)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
