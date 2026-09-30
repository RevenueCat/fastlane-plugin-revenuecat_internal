require 'fastlane/action'
require 'fastlane_core/configuration/config_item'

module Fastlane
  module Actions
    class CiPullRequestContextAction < Action
      PULL_REQUEST_URL = %r{/pull/(?<pr_number>\d+)/?\z}.freeze
      MERGE_QUEUE_BRANCH = %r{\Agh-readonly-queue/(?<base_ref>.+)/pr-(?<pr_number>\d+)-(?<base_sha>[0-9a-f]+)\z}.freeze

      def self.run(params)
        pull_request_match = params[:pull_request_url].to_s.strip.match(PULL_REQUEST_URL)
        return { pr_number: pull_request_match[:pr_number] } if pull_request_match

        branch = params[:branch].to_s.strip
        branch = Actions.git_branch.to_s.strip if branch.empty?
        merge_queue_match = branch.match(MERGE_QUEUE_BRANCH)
        return {} unless merge_queue_match

        {
          pr_number: merge_queue_match[:pr_number],
          base_ref: merge_queue_match[:base_ref],
          base_sha: merge_queue_match[:base_sha]
        }
      end

      def self.description
        'Returns the current CircleCI pull-request context, including merge-queue base metadata when available.'
      end

      def self.authors
        ['Rick van der Linden']
      end

      def self.return_value
        'Hash containing pr_number and, for merge-queue builds, base_ref and base_sha; otherwise an empty hash.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :pull_request_url,
                                       env_name: 'CIRCLE_PULL_REQUEST',
                                       description: 'CircleCI pull-request URL',
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :branch,
                                       env_name: 'CIRCLE_BRANCH',
                                       description: 'CircleCI branch; falls back to the current Git branch',
                                       optional: true,
                                       type: String)
        ]
      end

      def self.is_supported?(_platform)
        true
      end
    end
  end
end
