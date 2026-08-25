require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/github_helper'

module Fastlane
  module Actions
    class ValidatePrApprovedAction < Action
      def self.run(params)
        github_token = params[:github_token]
        pr_url = params[:pr_url]

        status = Helper::GitHubHelper.pr_approval_status(pr_url, github_token)

        log_reviews(status[:reviews])

        if status[:approved]
          UI.success("PR has been approved by an organization member with write permissions")
        else
          UI.user_error!(missing_approval_error(status, pr_url))
        end
      end

      private_class_method def self.log_reviews(reviews)
        if reviews.empty?
          UI.important("No reviews found on this PR")
          return
        end

        UI.message("Reviews found on this PR:")
        reviews.each { |review| UI.message("  - #{describe_review(review)}") }
      end

      private_class_method def self.describe_review(review)
        case review[:state]
        when 'APPROVED'
          "#{review[:username]} approved it with '#{review[:permission]}' permission"
        when 'CHANGES_REQUESTED'
          "#{review[:username]} requested changes"
        else
          "#{review[:username]}'s review was dismissed"
        end
      end

      private_class_method def self.missing_approval_error(status, pr_url)
        <<~ERROR
          #{missing_approval_reason(status)}

          The release can't be tagged until the release PR is approved on GitHub. Open it, review the
          changes and submit an "Approve" review, then re-run this job:
          #{pr_url}

          Note that approving the hold step in CircleCI is not the same thing: this check only looks
          at reviews on the GitHub PR.
        ERROR
      end

      private_class_method def self.missing_approval_reason(status)
        approvers_without_write_access = status[:approvers_without_write_access]
        changes_requested_by = status[:changes_requested_by]
        dismissed_reviews_by = status[:dismissed_reviews_by]

        if !approvers_without_write_access.empty?
          lacks_access = approvers_without_write_access.size == 1 ? "that account doesn't" : "none of those accounts"
          "The release PR is approved by #{join_names(approvers_without_write_access)}, but #{lacks_access} " \
            "have write access to #{status[:repo]}, so the approval doesn't authorize a release."
        elsif !changes_requested_by.empty?
          "#{join_names(changes_requested_by)} requested changes on the release PR and nobody has approved it since."
        elsif !dismissed_reviews_by.empty?
          "The review on the release PR by #{join_names(dismissed_reviews_by)} was dismissed, so the PR is no longer approved."
        else
          "No approvals found on the release PR."
        end
      end

      private_class_method def self.join_names(names)
        return names.first if names.size == 1

        "#{names[0..-2].join(', ')} and #{names.last}"
      end

      def self.description
        "Validates that the current PR is approved by an organization member with write permissions"
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
                                       description: "GitHub API token",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :pr_url,
                                       env_name: "CIRCLE_PULL_REQUEST",
                                       description: "URL of the pull request to check",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
