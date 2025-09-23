require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'
require 'fastlane/actions/last_git_commit'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class GitHubHelper
      SUPPORTED_PR_LABELS = (%w[breaking build ci docs feat fix perf revenuecatui refactor style test next_release dependencies phc_dependencies force_minor force_patch revenuecatui].map { |label| "pr:#{label}" }).to_set

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

      def self.check_authentication_and_rate_limits(github_token)
        if github_token.nil? || github_token.empty?
          UI.message("No GitHub token provided - requests will be unauthenticated (60 req/hour)")
          return { authenticated: false, primary_limit: 60 }
        end

        begin
          # Get rate limit status (doesn't count against rate limit)
          response = Actions::GithubApiAction.run(
            server_url: 'https://api.github.com',
            path: '/rate_limit',
            http_method: 'GET',
            api_token: github_token
          )

          rate_data = JSON.parse(response[:body].force_encoding('UTF-8'))
          core_remaining = rate_data.dig('resources', 'core', 'remaining') || 0
          core_limit = rate_data.dig('resources', 'core', 'limit') || 0

          UI.message("GitHub rate limit: #{core_remaining}/#{core_limit} remaining")

          return { authenticated: core_limit > 60, rate_limit_remaining: core_remaining }
        rescue StandardError => e
          UI.message("Could not check rate limits: #{e.message}")
          return { authenticated: false, error: e.message }
        end
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

      # This is a temporary workaround as the fastlane action does not support the `make_latest` parameter
      # Forked from: https://github.com/fastlane/fastlane/blob/master/fastlane/lib/fastlane/actions/set_github_release.rb
      def self.create_github_release(params)
        UI.important("Creating release of #{params[:repository_name]} on tag \"#{params[:tag_name]}\" with name \"#{params[:name]}\".")
        UI.important("Will also upload assets #{params[:upload_assets]}.") if params[:upload_assets]

        repo_name = params[:repository_name]
        api_token = params[:api_token]
        server_url = params[:server_url]
        tag_name = params[:tag_name]

        payload = {
          'tag_name' => params[:tag_name],
          'draft' => !!params[:is_draft],
          'prerelease' => !!params[:is_prerelease],
          'generate_release_notes' => !!params[:is_generate_release_notes],
          'make_latest' => (!!params[:make_latest]).to_s
        }
        payload['name'] = params[:name] if params[:name]
        payload['body'] = params[:description] if params[:description]
        payload['target_commitish'] = params[:commitish] if params[:commitish]

        response = Actions::GithubApiAction.run(
          server_url: server_url,
          api_token: api_token,
          http_method: 'POST',
          path: "repos/#{repo_name}/releases",
          body: payload,
          error_handlers: {
            422 => proc do |result|
              UI.error(result[:body])
              UI.error("Release on tag #{tag_name} already exists!")
              return nil
            end,
            404 => proc do |result|
              UI.error(result[:body])
              UI.user_error!("Repository #{repo_name} cannot be found, please double check its name and that you provided a valid API token")
            end,
            401 => proc do |result|
              UI.error(result[:body])
              UI.user_error!("You are not authorized to access #{repo_name}, please make sure you provided a valid API token")
            end,
            '*' => proc do |result|
              UI.user_error!("GitHub responded with #{result[:status]}:#{result[:body]}")
            end
          }
        )

        json = JSON.parse(response[:body])
        html_url = json['html_url']

        UI.success("Successfully created release at tag \"#{tag_name}\" on GitHub")
        UI.important("See release at \"#{html_url}\"")

        assets = params[:upload_assets]
        if assets && assets.count > 0
          upload_assets(assets, json['upload_url'], api_token)
          UI.success("Successfully uploaded assets #{assets} to release \"#{html_url}\"")
        end

        json || response[:body]
      end

      def self.upload_assets(assets, upload_url_template, api_token)
        require 'addressable/template'

        assets.each do |asset_path|
          absolute_path = File.absolute_path(asset_path)
          UI.user_error!("Asset #{absolute_path} doesn't exist") unless File.exist?(absolute_path)

          if File.directory?(absolute_path)
            Dir.mktmpdir do |dir|
              tmpzip = File.join(dir, "#{File.basename(absolute_path)}.zip")
              puts("cd \"#{File.dirname(absolute_path)}\"; zip -r --symlinks \"#{tmpzip}\" \"#{File.basename(absolute_path)}\" 2>&1 >/dev/null")
              system("cd \"#{File.dirname(absolute_path)}\"; zip -r --symlinks \"#{tmpzip}\" \"#{File.basename(absolute_path)}\" 2>&1 >/dev/null")
              upload_single_asset(tmpzip, upload_url_template, api_token)
            end
          else
            upload_single_asset(absolute_path, upload_url_template, api_token)
          end
        end
      end

      def self.upload_single_asset(file, url_template, api_token)
        require 'addressable/template'

        file_name = File.basename(file)
        expanded_url = Addressable::Template.new(url_template).expand(name: file_name).to_s
        headers = { 'Content-Type' => 'application/zip' }

        UI.important("Uploading #{file_name}")

        Actions::GithubApiAction.run(
          api_token: api_token,
          http_method: 'POST',
          headers: headers,
          url: expanded_url,
          raw_body: File.read(file),
          error_handlers: {
            '*' => proc do |result|
              UI.error("GitHub responded with #{result[:status]}:#{result[:body]}")
              UI.user_error!("Failed to upload asset #{file_name} to GitHub.")
            end
          }
        )

        UI.success("Successfully uploaded #{file_name}.")
      end
    end
  end
end
