require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'rest-client'
require 'json'
require 'uri'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class MavenCentralHelper
      REPO1_BASE_URL = 'https://repo1.maven.org/maven2'.freeze

      def self.check_version_not_published(version, group_id, artifact_ids, auth_token)
        if auth_token.nil? || auth_token.empty?
          UI.user_error!("FETCH_PUBLICATIONS_USER_TOKEN_MAVEN_CENTRAL environment variable is not set. Please provide a valid token to check Maven Central publications.")
        end

        base_url = "https://central.sonatype.com/api/v1/publisher/published"
        existing_artifacts = []

        artifact_ids.each do |artifact_id|
          # Build query parameters for the API endpoint with proper URI encoding
          # The API uses 'name' parameter which corresponds to the artifact_id
          api_url = "#{base_url}?namespace=#{URI.encode_www_form_component(group_id)}&name=#{URI.encode_www_form_component(artifact_id)}&version=#{URI.encode_www_form_component(version)}"

          UI.verbose("Checking Sonatype API for publication status: #{group_id}:#{artifact_id}:#{version}")

          begin
            response = RestClient.get(
              api_url,
              {
                'Authorization' => "Bearer #{auth_token}",
                'accept' => 'application/json'
              }
            )

            # Parse JSON response
            response_data = JSON.parse(response.body)

            # Check if published field is true
            if response_data["published"] == true
              existing_artifacts << artifact_id
              UI.important("Artifact #{group_id}:#{artifact_id}:#{version} already exists in Maven Central")
            end
          rescue StandardError => e
            UI.user_error!("Failed to check #{group_id}:#{artifact_id}:#{version}: #{e.message}")
          end
        end

        unless existing_artifacts.empty?
          error_message = "Version #{version} already exists in Maven Central for the following artifacts:\n"
          existing_artifacts.each do |artifact_id|
            error_message += "  - #{group_id}:#{artifact_id}:#{version}\n"
          end
          error_message += "\nDeployment cancelled to prevent duplicate releases."
          UI.user_error!(error_message)
        end

        true
      end

      # Gradle's mavenCentral() resolves a dependency by fetching its POM from repo1.
      def self.pom_url(group_id, artifact_id, version)
        "#{REPO1_BASE_URL}/#{group_id.tr('.', '/')}/#{artifact_id}/#{version}/#{artifact_id}-#{version}.pom"
      end

      def self.artifact_available?(group_id, artifact_id, version)
        RestClient.head(pom_url(group_id, artifact_id, version), { 'Cache-Control' => 'no-cache' })
        true
      rescue RestClient::NotFound
        false
      rescue StandardError => e
        UI.important("Couldn't check #{group_id}:#{artifact_id}:#{version} on Maven Central: #{e.message}")
        false
      end

      def self.wait_for_artifacts(group_id, artifact_ids, version, timeout_seconds, poll_interval_seconds, soft_fail)
        deadline = Time.now + timeout_seconds

        artifact_ids.each do |artifact_id|
          next if wait_for_artifact(group_id, artifact_id, version, deadline, poll_interval_seconds)

          message = "#{group_id}:#{artifact_id}:#{version} still isn't on Maven Central after #{timeout_seconds / 60}m."
          UI.user_error!("#{message} Giving up.") unless soft_fail
          UI.important("#{message} Continuing anyway.")
        end
      end

      def self.wait_for_artifact(group_id, artifact_id, version, deadline, poll_interval_seconds)
        loop do
          if artifact_available?(group_id, artifact_id, version)
            UI.success("#{group_id}:#{artifact_id}:#{version} is available on Maven Central")
            return true
          end

          remaining = deadline - Time.now
          return false if remaining <= 0

          UI.message("Waiting for #{group_id}:#{artifact_id}:#{version} on Maven Central " \
                     "(#{(remaining / 60).ceil}m remaining)...")
          sleep([poll_interval_seconds, remaining].min)
        end
      end
    end
  end
end
