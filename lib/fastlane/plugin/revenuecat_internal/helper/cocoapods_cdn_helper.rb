require 'digest'
require 'fastlane_core/ui/ui'
require 'rest-client'
require_relative 'polling_helper'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class CocoapodsCdnHelper
      CDN_BASE_URL = 'https://cdn.cocoapods.org'

      # Returns { pod name => version } for every dependency in the given podspecs
      # whose name matches pod_name_pattern.
      def self.pinned_pods_in_podspecs(podspec_paths, pod_name_pattern)
        dependency_regex = /spec\.dependency\s+["'](#{pod_name_pattern})["']\s*,\s*["']([^"']+)["']/

        podspec_paths.each_with_object({}) do |podspec_path, pods|
          UI.user_error!("Podspec not found: #{podspec_path}") unless File.exist?(podspec_path)

          File.read(podspec_path).scan(dependency_regex) do |pod_name, version|
            pods[pod_name] = version
          end
        end
      end

      # The CDN shards its index by the first three hex characters of the MD5 of the
      # pod name, with one line per pod: "<name>/<version>/<version>/...". Versions
      # are sorted lexicographically, so never assume the last one is the newest.
      def self.versions_url(pod_name)
        hash = Digest::MD5.hexdigest(pod_name)
        "#{CDN_BASE_URL}/all_pods_versions_#{hash[0]}_#{hash[1]}_#{hash[2]}.txt"
      end

      def self.published_versions(pod_name)
        response = RestClient.get(versions_url(pod_name), { 'Cache-Control' => 'no-cache' })
        line = response.body.each_line.find { |candidate| candidate.start_with?("#{pod_name}/") }
        line ? line.strip.split('/').drop(1) : []
      rescue StandardError => e
        # A lookup failure is indistinguishable from "not published yet" for our
        # purposes, so warn and let the caller keep polling.
        UI.important("Couldn't read the CocoaPods CDN index for #{pod_name}: #{e.message}")
        []
      end

      def self.wait_for_pods(pods, timeout_seconds, poll_interval_seconds, soft_fail)
        checks = pods.to_h do |pod_name, version|
          ["#{pod_name} #{version}", -> { published_versions(pod_name).include?(version) }]
        end
        PollingHelper.wait_for_all(checks, 'the CocoaPods CDN', timeout_seconds, poll_interval_seconds, soft_fail)
      end
    end
  end
end
