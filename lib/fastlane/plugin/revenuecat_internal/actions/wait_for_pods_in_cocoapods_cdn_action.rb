require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require_relative '../helper/cocoapods_cdn_helper'

module Fastlane
  module Actions
    class WaitForPodsInCocoapodsCdnAction < Action
      # Three hours. A newly published pod takes a while to propagate from trunk to
      # cdn.cocoapods.org, and it has been observed taking over two.
      DEFAULT_TIMEOUT_SECONDS = 10_800
      DEFAULT_POLL_INTERVAL_SECONDS = 60
      DEFAULT_POD_NAME_PATTERN = 'PurchasesHybridCommon\w*'.freeze

      def self.run(params)
        pods = params[:pods] || pods_from_podspecs(params)
        if pods.empty?
          UI.user_error!('Found no pods to wait for. Check :pods, or that :podspec_paths contain a matching dependency.')
        end

        summary = pods.map { |pod_name, version| "#{pod_name} #{version}" }.join(', ')
        UI.message("Waiting for #{pods.size} pod(s) to be available on the CocoaPods CDN: #{summary}")

        Helper::CocoapodsCdnHelper.wait_for_pods(
          pods,
          params[:timeout],
          params[:poll_interval],
          params[:soft_fail]
        )
      end

      def self.pods_from_podspecs(params)
        podspec_paths = params[:podspec_paths]
        if podspec_paths.nil? || podspec_paths.empty?
          UI.user_error!('Either :pods or :podspec_paths must be provided')
        end

        Helper::CocoapodsCdnHelper.pinned_pods_in_podspecs(podspec_paths, params[:pod_name_pattern])
      end

      def self.description
        "Waits until the given pod versions are available on the CocoaPods CDN"
      end

      def self.details
        [
          "A pod pushed to trunk isn't immediately resolvable by `pod install`, which fails with",
          '"CocoaPods could not find compatible versions for pod" until the CDN index catches up.',
          "Gate iOS CI jobs on this action so they don't start expensive work against a pod that",
          "isn't there yet."
        ].join(' ')
      end

      def self.authors
        ["RevenueCat"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :pods,
                                       description: "Hash of pod name to version to wait for. Takes precedence over :podspec_paths",
                                       optional: true,
                                       type: Hash),
          FastlaneCore::ConfigItem.new(key: :podspec_paths,
                                       description: "Paths to podspecs to read the pinned versions from, when :pods isn't given",
                                       optional: true,
                                       type: Array),
          FastlaneCore::ConfigItem.new(key: :pod_name_pattern,
                                       description: "Pattern matching the dependency names to extract from :podspec_paths",
                                       optional: true,
                                       default_value: DEFAULT_POD_NAME_PATTERN,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :timeout,
                                       description: "How many seconds to wait before giving up",
                                       optional: true,
                                       default_value: DEFAULT_TIMEOUT_SECONDS,
                                       type: Integer),
          FastlaneCore::ConfigItem.new(key: :poll_interval,
                                       description: "How many seconds to wait between CDN checks",
                                       optional: true,
                                       default_value: DEFAULT_POLL_INTERVAL_SECONDS,
                                       type: Integer),
          FastlaneCore::ConfigItem.new(key: :soft_fail,
                                       description: "Warn and continue instead of failing when the timeout is reached",
                                       optional: true,
                                       default_value: false,
                                       type: Boolean)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
