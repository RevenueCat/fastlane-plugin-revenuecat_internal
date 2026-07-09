require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require 'open3'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class GenerateMobileAppReleaseNotesAction < Action
      PROMPT_PATH = File.expand_path('../assets/mobile_app_release_notes_prompt.md', __dir__)

      STORE_INSTRUCTIONS = {
        'ios' => "These notes are for the App Store \"What's New\" section.",
        'android' => "These notes are for the Google Play \"What's new\" section. " \
                     "The full text must not exceed 500 characters."
      }.freeze

      def self.run(params)
        platform = params[:platform]
        store_instructions = STORE_INSTRUCTIONS[platform]
        if store_instructions.nil?
          UI.user_error!("Unsupported platform '#{platform}'. Supported platforms: #{STORE_INSTRUCTIONS.keys.join(', ')}")
        end

        prompt = <<~PROMPT
          #{File.read(PROMPT_PATH)}

          ## Target store

          #{store_instructions}

          ## Changes in this release

          #{params[:changes]}

          Reply with ONLY the release notes text — no preamble, no explanation, no markdown code fences.
        PROMPT

        command = [params[:claude_binary], '-p', '--model', params[:model]]
        stdout, stderr, status = Open3.capture3(*command, stdin_data: prompt)
        UI.user_error!("Generating release notes with '#{command.join(' ')}' failed: #{stderr}") unless status.success?

        release_notes = stdout.strip
        UI.user_error!("Generating release notes produced empty output") if release_notes.empty?

        UI.message("Generated release notes:\n#{release_notes}")
        release_notes
      end

      def self.description
        "Generates customer-facing release notes for the RevenueCat mobile app in the on-brand voice using the Claude CLI"
      end

      def self.return_value
        "The generated release notes as a String"
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :changes,
                                       description: "The list of changes in this release, one per line",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :platform,
                                       description: "Store to target: ios (App Store) or android (Google Play)",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :claude_binary,
                                       description: "Path to the Claude CLI binary",
                                       optional: true,
                                       default_value: "claude",
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :model,
                                       description: "Model to use for generation",
                                       optional: true,
                                       default_value: "claude-sonnet-4-6",
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
