module Fastlane
  module Actions
    
    class PodPushWithErrorHandlingAction < Action
      def self.run(params)
        begin
          # Capture the output of pod_push
          UI.message("🚀 Running pod_push with path: #{params[:path]}")
          
          output = Fastlane::Actions::PodPushAction.run(
            path: params[:path],
            synchronous: true 
          )

          return true
        rescue => e
          output_str = e.message

          if output_str.include?("[!] Unable to accept duplicate entry for:")
            UI.error("⚠️ Duplicate entry detected. Skipping push.")
            return false
          end

          UI.error("❌ Pod push failed: #{e.message}")
          UI.user_error!("Pod push failed.")
        end
      end

      def self.description
        "Pushes a podspec to CocoaPods and gracefully handles duplicate entry errors"
      end

      def self.authors
        ["Your Name"]
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
          )
        ]
      end
    end
  end
end
