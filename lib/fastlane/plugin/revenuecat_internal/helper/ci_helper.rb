require 'fastlane/action'

module Fastlane
  module Helper
    class CiHelper
      PULL_REQUEST_URL = %r{/pull/(?<pr_number>\d+)/?\z}
      MERGE_QUEUE_BRANCH = %r{\Agh-readonly-queue/(?<base_ref>.+)/pr-(?<pr_number>\d+)-(?<base_sha>[0-9a-f]+)\z}

      def self.pull_request_context(pull_request_url: nil, head_sha: nil, head_ref: nil)
        pull_request_url = circleci_value(pull_request_url, 'CIRCLE_PULL_REQUEST')
        head_sha = circleci_value(head_sha, 'CIRCLE_SHA1')
        head_ref = circleci_value(head_ref, 'CIRCLE_BRANCH')

        pull_request_match = pull_request_url.match(PULL_REQUEST_URL)
        head_ref = resolve_head_ref(head_ref)
        merge_queue_match = head_ref.match(MERGE_QUEUE_BRANCH)
        return {} unless pull_request_match || merge_queue_match

        context = {
          pr_number: merge_queue_match ? merge_queue_match[:pr_number] : pull_request_match[:pr_number],
          head_sha: resolve_head_sha(head_sha),
          head_ref: head_ref == 'HEAD' ? nil : head_ref
        }
        context.merge!(merge_queue_base_metadata(merge_queue_match)) if merge_queue_match
        context.compact
      end

      def self.circleci_value(value, environment_variable)
        value = value.to_s.strip
        value.empty? ? ENV.fetch(environment_variable, '').strip : value
      end
      private_class_method :circleci_value

      def self.resolve_head_ref(head_ref)
        head_ref.empty? ? Actions.git_branch_name_using_HEAD.to_s.strip : head_ref
      end
      private_class_method :resolve_head_ref

      def self.resolve_head_sha(head_sha)
        head_sha.empty? ? Actions.last_git_commit_hash(false).to_s.strip : head_sha
      end
      private_class_method :resolve_head_sha

      def self.merge_queue_base_metadata(merge_queue_match)
        {
          base_ref: merge_queue_match[:base_ref],
          base_sha: merge_queue_match[:base_sha]
        }
      end
      private_class_method :merge_queue_base_metadata
    end
  end
end
