require 'fastlane/action'
require 'fastlane_core/ui/ui'
require 'fastlane_core/configuration/config_item'

module Fastlane
  module Actions
    class PodPushUnknownError < StandardError; end

    class PodPushWithErrorHandlingAction < Action
      def self.run(params)
        UI.message("🚀 Running pod_push with path: #{params[:path]}")

        Fastlane::Actions::PodPushAction.run(
          path: params[:path],
          synchronous: params[:synchronous],
          verbose: params[:verbose],
          allow_warnings: params[:allow_warnings]
        )

        true
      rescue StandardError => e
        output_str = e.message

        if output_str.include?("[!] Unable to accept duplicate entry for:")
          UI.error("⚠️ Duplicate entry detected. Skipping push.")
          return false
        end

        raise PodPushUnknownError, "❌ Pod push failed: #{e.message}"
      end

      def self.description
        "Pushes a podspec to CocoaPods with support for synchronous, verbose, and allow_warnings options."
      end

      def self.authors
        ["facumenzella"]
      end

      def self.return_value
        "Returns false if the push is skipped due to a duplicate entry, true if successful."
      end

      def self.details
        "A custom Fastlane action that wraps `pod_push` and supports all relevant parameters."
      end

      def self.is_supported?(platform)
        [:ios, :mac].include?(platform)
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(
            key: :path,
            description: "Path to the .podspec file",
            optional: false,
            type: String
          ),
          FastlaneCore::ConfigItem.new(
            key: :synchronous,
            description: "Wait for push to complete before returning",
            optional: true,
            type: TrueClass,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :verbose,
            description: "Show more debugging output",
            optional: true,
            type: TrueClass,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :allow_warnings,
            description: "Allow warnings when pushing the podspec",
            optional: true,
            type: TrueClass,
            default_value: false
          )
        ]
      end
    end
  end
end