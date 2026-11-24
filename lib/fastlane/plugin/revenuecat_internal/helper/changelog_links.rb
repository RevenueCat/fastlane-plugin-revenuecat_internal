require 'fastlane/action'
require 'tmpdir'
require 'uri'

module Fastlane
  module Helper
    class ChangelogLinks
      def initialize(internal_repo_name, public_repo_name, release_tag)
        @internal_repo_url = "https://github.com/RevenueCat/#{internal_repo_name}"
        @public_repo_url = "https://github.com/RevenueCat/#{public_repo_name}"
        @public_repo_name = public_repo_name
        @release_tag = release_tag
      end

      def line(entry)
        title, title_newline, title_notes = entry.title.partition("\n")
        title, external_credit = external_contribution(title, entry.pull_request)
        attribution, newline, extra_notes = entry.attribution.partition("\n")
        pr_number = entry.pull_request&.dig('number')
        internal_pr = " ([internal ##{pr_number}](#{@internal_repo_url}/pull/#{pr_number}))" if pr_number

        change = "* #{title}#{public_reference(entry.source_sha)}#{external_credit}#{attribution}#{internal_pr}"
        "#{change}#{title_newline}#{title_notes}#{newline}#{extra_notes}"
      end

      private

      def public_reference(source_sha)
        public_sha = public_commits[source_sha] if source_sha
        return " ([`#{public_sha[0, 7]}`](#{@public_repo_url}/commit/#{public_sha}))" if public_sha
        return '' unless @release_tag

        " ([public release snapshot](#{@public_repo_url}/tree/#{URI.encode_www_form_component(@release_tag)}))"
      end

      def public_commits
        @public_commits ||= Dir.mktmpdir('sdk-changelog-') do |directory|
          # Only commit objects are needed to read their SHAs and Copybara trailers.
          Actions.sh('git', 'clone', '--bare', '--single-branch', '--no-tags', '--filter=tree:0', "#{@public_repo_url}.git", directory, log: false)
          history = Actions.sh('git', '-C', directory, 'log', '--format=%H%x09%(trailers:key=GitOrigin-RevId,valueonly,separator=%x2C)', log: false)
          history.each_line.each_with_object({}) do |line, commits|
            public_sha, origin_sha = line.split
            commits[public_sha] ||= public_sha
            commits[origin_sha] ||= public_sha if origin_sha&.match?(/\A[0-9a-f]{40}\z/)
          end
        end
      end

      def external_contribution(title, pull_request)
        return [title, nil] unless pull_request

        repo = Regexp.escape(@public_repo_name)
        reference = title.match(%r{\s+\((?:RevenueCat/#{repo})?#(\d+)\) (?:via|by) @([a-z0-9-]+)\z}i)
        return [title, nil] unless reference

        number, contributor = reference.captures
        url = "#{@public_repo_url}/pull/#{number}"
        legacy_import = title.start_with?('[EXTERNAL] ')
        return [title, nil] unless legacy_import || pull_request['body'].to_s.start_with?("Imports #{url} by @#{contributor} at ")

        title = reference.pre_match
        title = "[EXTERNAL] #{title}" unless legacy_import
        [title, " via **@#{contributor}** ([##{number}](#{url}))"]
      end
    end
  end
end
