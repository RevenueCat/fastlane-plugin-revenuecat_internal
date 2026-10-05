require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/ci_helper'

module Fastlane
  module Actions
    class CiPullRequestContextAction < Action
      def self.run(params)
        Helper::CiHelper.pull_request_context(
          pull_request_url: params[:pull_request_url],
          head_sha: params[:head_sha],
          head_ref: params[:head_ref]
        )
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
