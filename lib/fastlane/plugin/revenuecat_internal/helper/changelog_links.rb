require 'fastlane_core/ui/ui'
require 'open3'
require 'tmpdir'
require 'uri'

module Fastlane
  module Helper
    class ChangelogLinks
      REPOSITORY_NAME = /\A[a-z0-9_.-]+\z/i
      COMMIT_SHA = /\A[0-9a-f]{40}\z/
      TITLE_PART = /(?<code>(?<ticks>(?<![\\\x60])\x60+(?!\x60)).*?(?<!\x60)\k<ticks>(?!\x60))|[^\x60]+|\x60+/

      def initialize(internal_repo_name, public_repo_name, snapshot_tag: nil)
        repo_names = { 'internal repository name (repo_name)' => internal_repo_name, 'public repository name (public_repo_name)' => public_repo_name }
        repo_names.each do |option, name|
          next if name.kind_of?(String) && name.valid_encoding? && REPOSITORY_NAME.match?(name) && name != '.' && name != '..'

          FastlaneCore::UI.user_error!("Invalid #{option} #{name.inspect}. Pass a GitHub repository name without an owner.")
        end
        @internal_repo = "RevenueCat/#{internal_repo_name}"
        @public_repo = "RevenueCat/#{public_repo_name}"
        @public_repo_url = "https://github.com/#{@public_repo}"
        @snapshot_tag = snapshot_tag
      end

      def line(entry)
        title, external_credit = external_contribution(entry.title, entry.pull_request)
        pr_number = entry.pull_request&.dig('number')
        if pr_number.kind_of?(Integer) && pr_number.positive?
          internal_pr = " (#{pull_request_link(@internal_repo, pr_number)})"
        end

        title = markdown_text(title, preserve_code: true) unless entry.title_is_markdown
        "* #{title}#{public_reference(entry.source_sha)}#{external_credit}#{markdown_text(entry.attribution)}#{internal_pr}#{entry.extra_notes}"
      end

      private

      def pull_request_link(repository, number)
        "[#{repository}##{number}](https://github.com/#{repository}/pull/#{number})"
      end

      def public_reference(source_sha)
        public_sha = public_commits[source_sha] if source_sha
        return " ([`#{public_sha[0, 7]}`](#{@public_repo_url}/commit/#{public_sha}))" if public_sha

        problem = if source_sha.nil?
                    "This change has no source commit SHA."
                  elsif public_commits.key?(source_sha)
                    "Multiple commits on the public default branch of #{@public_repo_url} claim source SHA #{source_sha}."
                  else
                    "Source commit #{source_sha} has no match on the public default branch of #{@public_repo_url}."
                  end
        if @snapshot_tag
          FastlaneCore::UI.important("#{problem} Using the public release snapshot for hotfix #{@snapshot_tag}.")
          return " ([public release snapshot](#{@public_repo_url}/tree/refs/tags/#{URI.encode_www_form_component(@snapshot_tag)}))"
        end

        FastlaneCore::UI.user_error!("#{problem} Check the Copybara export and rerun release prep once the public commit can be resolved.")
      end

      def public_commits
        @public_commits ||= Dir.mktmpdir('sdk-changelog-') do |directory|
          # Only commit objects are needed to read their SHAs and Copybara trailers.
          git(directory, '-c', 'credential.helper=', '-c', 'core.askPass=', '-c', 'http.lowSpeedLimit=1', '-c', 'http.lowSpeedTime=30',
              'clone', '--quiet', '--bare', '--single-branch', '--no-tags', '--filter=tree:0', "#{@public_repo_url}.git", '.')
          history = git(directory, 'log', '-z', '--format=%H%x09%(trailers:key=GitOrigin-RevId,valueonly,unfold,separator=%x2C)')
          public_shas = {}
          origins = {}
          history.split("\0").each do |record|
            public_sha, origin_sha = record.split("\t", 2)
            next unless COMMIT_SHA.match?(public_sha)

            public_shas[public_sha] = public_sha
            # A duplicate origin is ambiguous. An exact public SHA still takes precedence.
            origins[origin_sha] = origins.key?(origin_sha) ? nil : public_sha if COMMIT_SHA.match?(origin_sha)
          end
          origins.merge(public_shas)
        end
      end

      def git(directory, *arguments)
        environment = { 'GIT_TERMINAL_PROMPT' => '0', 'GIT_ASKPASS' => nil, 'SSH_ASKPASS' => nil, 'GIT_DIR' => nil, 'GIT_WORK_TREE' => nil }
        stdout, _stderr, status = Open3.capture3(environment, 'git', *arguments, chdir: directory, binmode: true)
        return stdout if status.success?

        FastlaneCore::UI.user_error!("Could not read public commit history from #{@public_repo_url}. Check the repository name and GitHub connectivity, then retry.")
      end

      def markdown_text(text, preserve_code: false)
        text = text.gsub(/\p{Bidi_Control}/, '').gsub(/[[:cntrl:]]/, ' ')
        return escape_markdown(text) unless preserve_code

        text.gsub(TITLE_PART) { |part| Regexp.last_match(:code) ? part : escape_markdown(part) }
      end

      def escape_markdown(text)
        text.gsub(/[\\\x60*\[\]<>~|&#]|(?<![[:alnum:]])_|_(?![[:alnum:]])/) { |character| "\\#{character}" }
      end

      def external_contribution(title, pull_request)
        return [title, nil] unless pull_request

        repo = Regexp.escape(@public_repo)
        reference = title.match(/\s+\((?:#{repo})?#(\d+)\) (?:via|by) @([a-z0-9-]+)\z/i)
        return [title, nil] unless reference

        number, contributor = reference.captures
        url = "#{@public_repo_url}/pull/#{number}"
        body = pull_request['body'].to_s
        copybara_import = body.start_with?("Imports #{url} by @#{contributor} at ")
        legacy_import = title.start_with?('[EXTERNAL] ')
        legacy_credit = body.lines.any? { |line| line.strip == "Contributed by @#{contributor} in #{url}" }
        return [title, nil] unless copybara_import || (legacy_import && legacy_credit)

        title = reference.pre_match
        title = "[EXTERNAL] #{title}" unless legacy_import
        [title, " via **@#{contributor}** (#{pull_request_link(@public_repo, number)})"]
      end
    end
  end
end
