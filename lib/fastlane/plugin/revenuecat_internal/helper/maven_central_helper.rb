require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'rest-client'
require 'json'
require 'uri'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class MavenCentralHelper
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
    end
  end
end
