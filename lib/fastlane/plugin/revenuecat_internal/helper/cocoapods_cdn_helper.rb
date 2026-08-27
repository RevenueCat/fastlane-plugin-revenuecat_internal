require 'digest'
require 'fastlane_core/ui/ui'
require 'rest-client'

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
        pods.each do |pod_name, version|
          next if wait_for_pod(pod_name, version, timeout_seconds, poll_interval_seconds)

          message = "#{pod_name} #{version} still isn't on the CocoaPods CDN after #{timeout_seconds / 60}m."
          UI.user_error!("#{message} Giving up.") unless soft_fail
          UI.important("#{message} Continuing anyway.")
        end
      end

      def self.wait_for_pod(pod_name, version, timeout_seconds, poll_interval_seconds)
        started = Time.now

        loop do
          if published_versions(pod_name).include?(version)
            UI.success("#{pod_name} #{version} is available on the CocoaPods CDN")
            return true
          end

          waited = Time.now - started
          return false if waited >= timeout_seconds

          # Logged on every poll so CI sees output and doesn't hit an inactivity timeout.
          UI.message("Waiting for #{pod_name} #{version} on the CocoaPods CDN " \
                     "(#{(waited / 60).floor}m elapsed of #{timeout_seconds / 60}m)...")
          sleep(poll_interval_seconds)
        end
      end
    end
  end
end
