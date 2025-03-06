require 'fastlane/action'
require 'fastlane_core/ui/ui'
require 'fastlane_core/configuration/config_item'
require 'fastlane/actions/pod_push'

module Fastlane
  module Actions
    class PodPushUnknownError < StandardError; end

    class PodPushWithErrorHandlingAction < Action
      MAX_RETRIES = 3
      INITIAL_DELAY = 5

      def self.run(params)
        attempts = 0

        while attempts < MAX_RETRIES + 1
          attempts += 1
          FastlaneCore::UI.message("🚀 Attempt #{attempts}: Running pod_push with path: #{params[:path]}")

          begin
            Fastlane::Actions::PodPushAction.run(
              path: params[:path],
              synchronous: params[:synchronous],
              verbose: params[:verbose],
              allow_warnings: params[:allow_warnings]
            )
            return true
          rescue StandardError => e
            output_str = e.message

            if output_str.include?("[!] Unable to accept duplicate entry for:")
              FastlaneCore::UI.error("⚠️ Duplicate entry detected. Skipping push.")
              return true
            end

            if output_str.include?("[!] Calling the GitHub commit API timed out.") && attempts <= MAX_RETRIES
              delay = INITIAL_DELAY * (2**(attempts - 1)) # Exponential backoff (5s → 10s → 20s)
              FastlaneCore::UI.important("⚠️ GitHub API timeout detected. Retrying in #{delay} seconds... (#{attempts}/#{MAX_RETRIES})")
              sleep(delay)
              next
            end

            FastlaneCore::UI.error("❌ Pod push failed after #{MAX_RETRIES} retries due to GitHub API timeouts.") if attempts > MAX_RETRIES
            return false if attempts > MAX_RETRIES

            raise PodPushUnknownError, "❌ Pod push failed: #{e.message}"
          end
        end

        false
      end

      def self.description
        'Pushes a podspec to CocoaPods with retry handling for GitHub timeouts.'
      end

      def self.authors
        ['facumenzella']
      end

      def self.return_value
        'Returns true if successful. Retries up to 3 times on GitHub API timeouts. Returns false if fails due to an unexpected error.'
      end

      def self.details
        'A custom Fastlane action that wraps `pod_push`, handles duplicate entry errors, and retries on GitHub API timeouts.'
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :path,
            description: 'Path to the .podspec file',
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :synchronous,
            description: 'Wait for push to complete before returning',
            optional: true,
            type: TrueClass,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :verbose,
            description: 'Show more debugging output',
            optional: true,
            type: TrueClass,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :allow_warnings,
            description: 'Allow warnings when pushing the podspec',
            optional: true,
            type: TrueClass,
            default_value: false
          )
        ]
      end
    end
  end
end
