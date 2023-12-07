require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require 'fastlane/actions/last_git_commit'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class GitHubHelper
      SUPPORTED_PR_LABELS = %w[breaking build ci docs feat fix perf revenuecatui refactor style test next_release dependencies phc_dependencies minor].to_set

      def self.get_pr_resp_items_for_sha(sha, github_token, rate_limit_sleep, repo_name, base_branch)
        if rate_limit_sleep > 0
          UI.message("Sleeping #{rate_limit_sleep} second(s) to avoid rate limit 🐌")
          sleep(rate_limit_sleep)
        end

        # Get pull request associate with commit message
        pr_resp = Actions::GithubApiAction.run(server_url: 'https://api.github.com',
                                               path: "/search/issues?q=repo:RevenueCat/#{repo_name}+is:pr+base:#{base_branch}+SHA:#{sha}",
                                               http_method: 'GET',
                                               body: {},
                                               api_token: github_token)
        body = JSON.parse(pr_resp[:body])
        items = body["items"]
        return items
      end

      def self.get_commits_since_old_version(github_token, old_version, repo_name)
        commit_head = Actions::LastGitCommitAction.run({})
        path = "/repos/RevenueCat/#{repo_name}/compare/#{old_version}...#{commit_head[:commit_hash]}"

        # Get all commits from previous version (tag) to HEAD
        resp = Actions::GithubApiAction.run(server_url: 'https://api.github.com',
                                            path: path,
                                            http_method: 'GET',
                                            body: {},
                                            api_token: github_token)
        body = JSON.parse(resp[:body])
        commits = body["commits"].reverse

        return commits
      end

      def self.get_releases_between_tags(github_token, start_tag_version, end_tag_version, repo_name)
        start_tag = Gem::Version.new(start_tag_version)
        end_tag = Gem::Version.new(end_tag_version)

        response = Actions::GithubApiAction.run(
          server_url: "https://api.github.com",
          http_method: 'GET',
          path: "repos/RevenueCat/#{repo_name}/releases?per_page=50",
          error_handlers: {
            404 => proc do |result|
              UI.user_error!("Repository #{repo_name} cannot be found, please double check its name and that you provided a valid API token (if it's a private repository).")
            end,
            401 => proc do |result|
              UI.user_error!("You are not authorized to access #{repo_name}, please make sure you provided a valid API token.")
            end,
            '*' => proc do |result|
              UI.user_error!("GitHub responded with #{result[:status]}:#{result[:body]}")
            end
          },
          api_token: github_token
        )

        all_releases = JSON.parse(response[:body])

        # Filters releases between tags
        all_releases.select do |release|
          version = Gem::Version.new(release["tag_name"])
          start_tag < version && version <= end_tag && !release["prerelease"]
        end
      end

      def self.get_pull_request_id(pull_request_number, github_token)
        query_id = <<-GRAPHQL
          query QueryId {
            repository(name: "revenuecat-docs", owner: "RevenueCat") {
              pullRequest(number: #{pull_request_number}) {
                id
              }
            }
          }
        GRAPHQL

        execute_github_graphql_request(
          github_token,
          query_id,
          "Pull request ID queried successfully!",
          "Error querying pull request. Pull request ID is nil."
        ) do |response|
          pull_request_id = JSON.parse(response.body)["data"]["repository"]["pullRequest"]["id"]
          return pull_request_id unless pull_request_id.nil?
        end
      end

      def self.enable_auto_merge(pull_request_id, github_token)
        query_id = <<-GRAPHQL
          mutation EnableAutoMerge {
            enablePullRequestAutoMerge(input: {pullRequestId: "#{pull_request_id}", mergeMethod: SQUASH}) {
                clientMutationId
            }
          }
        GRAPHQL

        execute_github_graphql_request(
          github_token,
          query_id,
          "Auto merge enabled successfully!",
          "Failed to enable auto merge."
        )
      end

      private_class_method def self.execute_github_graphql_request(github_token, graphql_query, success_message, error_message)
        url = URI('https://api.github.com/graphql')
        http = Net::HTTP.new(url.host, url.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(url.request_uri)
        request.basic_auth(github_token, '')
        request.body = { query: graphql_query }.to_json

        response = http.request(request)
        if response.is_a?(Net::HTTPSuccess)
          Fastlane::UI.message(success_message)
          yield(response) if block_given?
        else
          Fastlane::UI.user_error!("#{error_message}\nCode: #{response.code}\nBody: #{response.read_body}")
        end
      end

    end
  end
end
