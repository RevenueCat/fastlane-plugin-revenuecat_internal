require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require 'fastlane/actions/last_git_commit'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class GitHubHelper
      SUPPORTED_PR_LABELS = %w[breaking build ci docs feat fix perf refactor style test next_release dependencies minor].to_set

      def self.get_pr_resp_items_for_sha(sha, github_token, rate_limit_sleep, repo_name)
        if rate_limit_sleep > 0
          UI.message("Sleeping #{rate_limit_sleep} second(s) to avoid rate limit 🐌")
          sleep(rate_limit_sleep)
        end

        # Get pull request associate with commit message
        pr_resp = Actions::GithubApiAction.run(server_url: 'https://api.github.com',
                                               path: "/search/issues?q=repo:RevenueCat/#{repo_name}+is:pr+base:main+SHA:#{sha}",
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
    end
  end
end
