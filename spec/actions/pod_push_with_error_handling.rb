module Fastlane
  module Actions
    class PodPushWithErrorHandlingAction < Action
      MAX_RETRIES = 3  # Number of retry attempts
      INITIAL_DELAY = 5 # Initial wait time in seconds

      def self.run(params)
        attempts = 0

        begin
          attempts += 1
          UI.message("🚀 Attempt #{attempts}: Running pod_push with path: #{params[:path]}")

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
          elsif output_str.include?("[!] Calling the GitHub commit API timed out.")
            if attempts < MAX_RETRIES
              delay = INITIAL_DELAY * (2**(attempts - 1)) # Exponential backoff (5s → 10s → 20s)
              UI.important("⚠️ GitHub API timeout detected. Retrying in #{delay} seconds... (#{attempts}/#{MAX_RETRIES})")
              sleep(delay)
              retry
            else
              UI.error("❌ Pod push failed after #{MAX_RETRIES} retries due to GitHub API timeouts.")
              return false
            end
          end

          UI.error("❌ Pod push failed: #{e.message}")
          UI.user_error!("Pod push failed.")
        end
      end

      def self.description
        "Pushes a podspec to CocoaPods, with retries for GitHub API timeouts and duplicate entry handling"
      end

      def self.authors
        ["Your Name"]
      end

      def self.return_value
        "Returns false if the push is skipped due to a duplicate entry or persistent GitHub timeout, true if successful."
      end

      def self.details
        "A custom Fastlane action that calls `pod_push`, handles duplicate entry errors, and retries on GitHub timeouts."
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