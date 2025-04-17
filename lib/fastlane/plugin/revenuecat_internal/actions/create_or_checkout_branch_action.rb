require 'fastlane/action'
require 'fastlane_core/configuration/config_item'
require 'fastlane_core/ui/ui'
require_relative '../helper/revenuecat_internal_helper'

module Fastlane
  module Actions
    class CreateOrCheckoutBranchAction < Action
      def self.run(params)
        branch_name = params[:branch_name]

        Helper::RevenuecatInternalHelper.create_or_checkout_branch(branch_name)
      end

      def self.description
        "Creates a new branch or checks out an existing branch. If the branch exists remotely but not locally, it will pull after checkout."
      end

      def self.authors
        ["Jay Shortway"]
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :branch_name,
                                       description: "Branch name to create or checkout",
                                       optional: false,
                                       type: String)
        ]
      end

      def self.is_supported?(platform)
        true
      end
    end
  end
end
