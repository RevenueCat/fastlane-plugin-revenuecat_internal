require 'fastlane/action'
require 'fastlane_core/ui/ui'
require 'fastlane_core/configuration/config_item'
require 'fastlane/actions/pod_push'
require 'fastlane/actions/read_podspec'
require 'net/http'
require 'json'
require 'uri'

module Fastlane
  module Actions
    class PodPushUnknownError < StandardError; end

    class PodPushWithErrorHandlingAction < Action
      MAX_RETRIES = 3
      INITIAL_DELAY = 5
      TRUNK_BASE_URL = 'https://trunk.cocoapods.org/api/v1/pods'

      def self.run(params)
        attempts = 0

        while attempts <= MAX_RETRIES
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
            # The push reported an error, but the pod may actually have been
            # published: it was already on trunk from a previous run, or this
            # push succeeded and only reported an error afterwards. `pod trunk
            # push` surfaces "duplicate entry" only in its output, which fastlane
            # truncates and omits from the raised error message when stdout is a
            # TTY (>= 2.237.0), so the message is unreliable. Ask trunk directly.
            if pod_published?(params[:path])
              FastlaneCore::UI.important("✅ Pod is already published to CocoaPods trunk. Treating the push as successful.")
              return true
            end

            # `pod trunk push` exits non-zero for every kind of failure, and
            # fastlane (>= 2.237.0) omits the underlying command output from the
            # raised error's message, so we can't reliably tell transient
            # failures (CocoaPods 500s, GitHub timeouts, stale spec index) apart
            # from permanent ones. Retry on any failure. A push that actually
            # published is already short-circuited by the pod_published? check
            # above, so retries can't turn into duplicate-entry failures.
            if attempts <= MAX_RETRIES
              delay = INITIAL_DELAY * (2**(attempts - 1))
              FastlaneCore::UI.important("⚠️ Pod push failed: #{e.message} Retrying in #{delay} seconds... (#{attempts}/#{MAX_RETRIES})")
              sleep(delay)
              next
            end

            FastlaneCore::UI.error("❌ Pod push failed after #{MAX_RETRIES} retries. You can rerun this job using SSH. Error: #{e.message}")
            raise PodPushUnknownError, "❌ Pod push failed: #{e.message}"
          end
        end

        false
      end

      # Returns true if the podspec's version is already published to CocoaPods
      # trunk. Used to recover from a push that failed but nonetheless published
      # the pod (or was already published). Any lookup failure returns false so
      # the caller keeps treating the push as failed rather than silently
      # swallowing a real error.
      def self.pod_published?(path)
        name, version = pod_name_and_version(path)
        return false if name.nil? || version.nil?

        published = trunk_has_version?(name, version)
        FastlaneCore::UI.message("ℹ️ #{name} #{version} is not yet published to CocoaPods trunk.") unless published
        published
      end

      def self.pod_name_and_version(path)
        spec = Fastlane::Actions::ReadPodspecAction.run(path: path)
        [spec['name'], spec['version']]
      rescue StandardError => e
        FastlaneCore::UI.important("⚠️ Could not read pod name/version from #{path}: #{e.message}")
        [nil, nil]
      end

      def self.trunk_has_version?(name, version)
        response = Net::HTTP.get_response(URI("#{TRUNK_BASE_URL}/#{name}"))
        return false unless response.kind_of?(Net::HTTPSuccess)

        versions = JSON.parse(response.body).fetch('versions', [])
        versions.any? { |entry| entry['name'] == version }
      rescue StandardError => e
        FastlaneCore::UI.important("⚠️ Could not verify whether #{name} #{version} is on CocoaPods trunk: #{e.message}")
        false
      end

      def self.description
        'Pushes a podspec to CocoaPods, retrying on failure and tolerating pods that are already published.'
      end

      def self.authors
        ['facumenzella']
      end

      def self.return_value
        'Returns true if the pod was pushed or is already on CocoaPods trunk. Retries up to 3 times on failure and raises PodPushUnknownError if all attempts fail.'
      end

      def self.details
        'A custom Fastlane action that wraps `pod_push`, treats an already-published pod as success by checking CocoaPods trunk, and retries on any push failure.'
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
