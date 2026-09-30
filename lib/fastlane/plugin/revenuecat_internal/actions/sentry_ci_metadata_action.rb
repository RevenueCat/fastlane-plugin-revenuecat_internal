require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/github_helper'

module Fastlane
  module Actions
    class SentryCiMetadataAction < Action
      MERGE_QUEUE_BRANCH = %r{\Agh-readonly-queue/(?<base_ref>.+)/pr-(?<pr_number>\d+)-(?<base_sha>[0-9a-f]+)\z}.freeze

      def self.run(params)
        repo_name = params[:repo_name]
        repo_owner = params[:repo_owner]
        head_sha = ENV['CIRCLE_SHA1'].to_s.strip
        head_sha = Actions.sh('git', 'rev-parse', 'HEAD', log: false).strip if head_sha.empty?

        head_ref = Actions.git_branch
        metadata = {
          org_slug: params[:org_slug],
          project_slug: params[:project_slug],
          vcs_provider: 'github',
          head_repo_name: "#{repo_owner}/#{repo_name}",
          base_repo_name: "#{repo_owner}/#{repo_name}",
          force_git_metadata: true,
          head_sha: head_sha,
          head_ref: head_ref == 'HEAD' ? nil : head_ref
        }

        merge_queue = head_ref.to_s.match(MERGE_QUEUE_BRANCH)
        if merge_queue
          metadata[:pr_number] = merge_queue[:pr_number]
          metadata[:base_ref] = merge_queue[:base_ref]
          metadata[:base_sha] = merge_queue[:base_sha]
        elsif (pr_number = pull_request_number)
          add_pull_request_metadata(metadata, pr_number, params, repo_owner, repo_name)
        end
        metadata.compact
      end

      def self.pull_request_number
        pull_request_url = ENV['CIRCLE_PULL_REQUEST'].to_s
        return pull_request_url.split('/').last if pull_request_url.include?('/')
      end

      def self.add_pull_request_metadata(metadata, pr_number, params, repo_owner, repo_name)
        github_token = github_token(params)
        if github_token.empty?
          UI.user_error!(
            'github_token, DANGER_GITHUB_API_TOKEN, or GITHUB_TOKEN is required for Sentry PR uploads'
          )
        end

        response = Helper::GitHubHelper.github_api_call_with_retry(
          server_url: 'https://api.github.com',
          api_token: github_token,
          http_method: 'GET',
          path: "/repos/#{repo_owner}/#{repo_name}/pulls/#{pr_number}"
        )
        pull_request = response[:json] || {}
        base_sha = pull_request.dig('base', 'sha')
        UI.user_error!("Could not determine the base SHA for PR ##{pr_number}") if base_sha.to_s.empty?

        metadata[:pr_number] = pr_number
        metadata[:base_sha] = base_sha
        metadata[:base_ref] = pull_request.dig('base', 'ref')
        metadata[:head_repo_name] = pull_request.dig('head', 'repo', 'full_name') || metadata[:head_repo_name]
        metadata[:base_repo_name] = pull_request.dig('base', 'repo', 'full_name') || metadata[:base_repo_name]
      end

      def self.github_token(params)
        explicit_token = params[:github_token].to_s.strip
        return explicit_token unless explicit_token.empty?

        danger_token = ENV['DANGER_GITHUB_API_TOKEN'].to_s.strip
        return danger_token unless danger_token.empty?

        ENV['GITHUB_TOKEN'].to_s.strip
      end

      def self.description
        'Builds consistent Sentry VCS metadata for CircleCI branch, pull-request, merge-queue, and main uploads.'
      end

      def self.authors
        ['Rick van der Linden']
      end

      def self.return_value
        'Hash of VCS metadata accepted by the Sentry build and snapshot Fastlane actions.'
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       description: 'GitHub repository name without its owner',
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :repo_owner,
                                       description: 'GitHub repository owner',
                                       optional: true,
                                       default_value: 'RevenueCat',
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :org_slug,
                                       description: 'Sentry organization slug',
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :project_slug,
                                       description: 'Sentry project slug',
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       env_name: 'DANGER_GITHUB_API_TOKEN',
                                       description: 'GitHub token used to resolve PR metadata; falls back to GITHUB_TOKEN',
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
