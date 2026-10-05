require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative 'ci_pull_request_context_action'

module Fastlane
  module Actions
    class SentryCiMetadataAction < Action
      def self.run(params)
        pull_request_context = CiPullRequestContextAction.run(
          pull_request_url: ENV.fetch('CIRCLE_PULL_REQUEST', nil),
          head_sha: ENV.fetch('CIRCLE_SHA1', nil),
          head_ref: ENV.fetch('CIRCLE_BRANCH', nil)
        )

        {
          org_slug: params[:org_slug],
          project_slug: params[:project_slug],
          force_git_metadata: true
        }.merge(pull_request_context)
      end

      def self.description
        'Builds Sentry upload metadata with normalized CircleCI pull-request context.'
      end

      def self.authors
        ['Rick van der Linden']
      end

      def self.return_value
        'Hash of VCS metadata accepted by the Sentry build and snapshot Fastlane actions.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :org_slug,
                                       description: 'Sentry organization slug',
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :project_slug,
                                       description: 'Sentry project slug',
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(_platform)
        true
      end
    end
  end
end
