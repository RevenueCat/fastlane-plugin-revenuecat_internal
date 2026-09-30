require 'fastlane/action'
require 'fastlane_core/configuration/config_item'

module Fastlane
  module Actions
    class CiPullRequestContextAction < Action
      PULL_REQUEST_URL = %r{/pull/(?<pr_number>\d+)/?\z}.freeze
      MERGE_QUEUE_BRANCH = %r{\Agh-readonly-queue/(?<base_ref>.+)/pr-(?<pr_number>\d+)-(?<base_sha>[0-9a-f]+)\z}.freeze

      def self.run(params)
        pull_request_match = params[:pull_request_url].to_s.strip.match(PULL_REQUEST_URL)
        head_ref = resolve_head_ref(params)
        merge_queue_match = head_ref.match(MERGE_QUEUE_BRANCH)
        return {} unless pull_request_match || merge_queue_match

        context = {
          pr_number: pull_request_match ? pull_request_match[:pr_number] : merge_queue_match[:pr_number],
          head_sha: resolve_head_sha(params),
          head_ref: head_ref == 'HEAD' ? nil : head_ref
        }
        context.merge!(merge_queue_base_metadata(merge_queue_match)) unless pull_request_match
        context.compact
      end

      def self.resolve_head_ref(params)
        head_ref = params[:head_ref].to_s.strip
        head_ref.empty? ? Actions.git_branch_name_using_HEAD.to_s.strip : head_ref
      end

      def self.resolve_head_sha(params)
        head_sha = params[:head_sha].to_s.strip
        head_sha.empty? ? Actions.last_git_commit_hash(false).to_s.strip : head_sha
      end

      def self.merge_queue_base_metadata(merge_queue_match)
        {
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
        'Hash containing PR head metadata and, for merge-queue builds, base_ref and base_sha; otherwise an empty hash.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :pull_request_url,
                                       env_name: 'CIRCLE_PULL_REQUEST',
                                       description: 'CircleCI pull-request URL',
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :head_sha,
                                       env_name: 'CIRCLE_SHA1',
                                       description: 'CircleCI commit SHA; falls back to the current Git commit',
                                       optional: true,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :head_ref,
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
