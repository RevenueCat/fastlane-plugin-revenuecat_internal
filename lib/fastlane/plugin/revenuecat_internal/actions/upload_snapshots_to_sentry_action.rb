require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/sentry_snapshots_helper'

module Fastlane
  module Actions
    class UploadSnapshotsToSentryAction < Action
      def self.run(params)
        if ENV["SENTRY_AUTH_TOKEN"].to_s.strip.empty?
          UI.user_error!("Set SENTRY_AUTH_TOKEN to upload snapshots.")
        end
        ENV["SENTRY_ORG"] = params[:org]
        ENV["SENTRY_PROJECT"] = params[:project]

        Helper::SentrySnapshotsHelper.upload_snapshots(
          export_dir: params[:export_dir],
          app_id: params[:app_id],
          sentry_cli: params[:sentry_cli_path],
          min_count: params[:min_count],
          main_branch: params[:main_branch],
          current_branch: Actions.git_branch
        )
      end

      def self.description
        "Uploads a directory of snapshot images to Sentry Snapshots: refuses partial runs that would corrupt the main baseline, " \
          "uploads only images that changed vs that baseline (Sentry bills per image), and falls back to a full upload " \
          "when no baseline exists or the diff fails."
      end

      def self.authors
        ["Josh Holtz"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :export_dir,
                                       description: "Directory of generated snapshot .png images (and optional .json sidecars)",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :app_id,
                                       description: "Sentry Snapshots app id; must stay consistent across uploads so head and base match",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :org,
                                       description: "Sentry organization slug",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :project,
                                       description: "Sentry project slug",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :sentry_cli_path,
                                       description: "Path to a sentry-cli binary with snapshots support (>= 3.5.0)",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :min_count,
                                       description: "Fail when fewer snapshots were generated; trips on partial runs",
                                       optional: false,
                                       type: Integer),
          FastlaneCore::ConfigItem.new(key: :main_branch,
                                       description: "Branch whose uploads form the shared baseline",
                                       optional: true,
                                       default_value: "main",
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
