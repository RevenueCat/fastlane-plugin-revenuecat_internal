require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require 'rest-client'
require 'json'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Actions
    class TriggerActionInCircleCiAction < Action
      def self.run(params)
        circle_token = params[:circle_token]
        UI.user_error!("Please set the CIRCLE_TOKEN environment variable") unless circle_token

        default_branch = Actions.git_branch
        branch = params[:branch] || default_branch

        headers = { "Circle-Token" => circle_token, "Content-Type" => "application/json", "Accept" => "application/json" }
        data = { parameters: { 'action' => params[:action] }, branch: branch }
        url = "https://circleci.com/api/v2/project/github/RevenueCat/#{params[:repo_name]}/pipeline"

        resp = RestClient.post(url, data.to_json, headers)

        number = JSON.parse(resp.body)["number"]
        workflow_url = "https://app.circleci.com/pipelines/github/RevenueCat/#{params[:repo_name]}/#{number}"

        UI.important("Workflow: #{workflow_url}")
      end

      def self.description
        "Triggers a CircleCI pipeline passing an action as a parameter"
      end

      def self.authors
        ["Cesar de la Vega"]
      end

      def self.return_value
        "The URL of the triggered CircleCI workflow"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :circle_token,
                                       env_name: "CIRCLE_TOKEN",
                                       description: "The CircleCI auth token",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :action,
                                       description: "The action to trigger",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :repo_name,
                                       env_name: "RC_INTERNAL_REPO_NAME",
                                       description: "Name of the repo of the SDK",
                                       optional: false,
                                       type: String),
          FastlaneCore::ConfigItem.new(key: :branch,
                                       description: "Branch to trigger the pipeline on, defaults to current branch",
                                       optional: true,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
