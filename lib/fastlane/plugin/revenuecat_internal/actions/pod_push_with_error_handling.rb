module Fastlane
  module Actions
    class PodPushUnknownError < StandardError; end 

    class PodPushWithErrorHandlingAction < Action
      def self.run(params)
        begin
          UI.message("🚀 Running pod_push with path: #{params[:path]}")
          
          output = Fastlane::Actions::PodPushAction.run(
            path: params[:path],
            synchronous: params[:synchronous],
            verbose: params[:verbose],
            allow_warnings: params[:allow_warnings]
          )

          return true
        rescue => e
          output_str = e.message

          if output_str.include?("[!] Unable to accept duplicate entry for:")
            UI.error("⚠️ Duplicate entry detected. Skipping push.")
            return false
          end

          UI.user_error!("❌ Pod push failed: #{e.message}")
          raise PodPushUnknownError, "❌ Pod push failed: #{e.message}"
        end
      end

      def self.description
        "Pushes a podspec to CocoaPods and gracefully handles duplicate entry errors"
      end

      def self.authors
        ["facumenzella"]
      end

      def self.return_value
        "Returns false if the push is skipped due to a duplicate entry, true if successful."
      end

      def self.details
        "A custom Fastlane action that calls `pod_push` and catches duplicate entry errors."
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
            type: Boolean,
            default_value: true
          ),
          FastlaneCore::ConfigItem.new(
            key: :verbose,
            description: "Show more debugging output",
            optional: true,
            type: Boolean,
            default_value: false
          ),
          FastlaneCore::ConfigItem.new(
            key: :allow_warnings,
            description: "Allow warnings when pushing the podspec",
            optional: true,
            type: Boolean,
            default_value: false
          )
        ]
      end
    end
  end
end
