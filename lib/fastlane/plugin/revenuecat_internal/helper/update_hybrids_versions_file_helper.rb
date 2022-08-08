require 'base64'
require 'fastlane_core/ui/ui'
require 'fastlane/action'
require 'fastlane/actions/github_api'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class UpdateHybridsVersionsFileHelper
      def self.get_android_version_for_hybrid_common_version(hybrid_common_version)
        path = 'android/build.gradle'
        repo_name = 'purchases-hybrid-common'
        contents = get_contents_file_github(path, repo_name, hybrid_common_version)
        matches = contents.match("ext.purchases_version = '(.*)'").captures
        UI.user_error!("Could not find android version in #{repo_name} in file '#{path}'") if matches.length != 1
        matches[0]
      end

      def self.get_ios_version_for_hybrid_common_version(hybrid_common_version)
        path = 'PurchasesHybridCommon.podspec'
        repo_name = 'purchases-hybrid-common'
        contents = get_contents_file_github(path, repo_name, hybrid_common_version)
        matches = contents.match("s.dependency 'RevenueCat', '(.*)'").captures
        UI.user_error!("Could not find ios version in #{repo_name} in file '#{path}'") if matches.length != 1
        matches[0]
      end

      private_class_method def self.get_contents_file_github(file_path, repo_name, ref = 'main')
        path = "/repos/revenuecat/#{repo_name}/contents/#{file_path}?ref=#{ref}"
        response = Actions::GithubApiAction.run(server_url: 'https://api.github.com',
                                                path: path,
                                                http_method: 'GET',
                                                body: {})
        base64_contents = response[:json]['content']
        Base64.decode64(base64_contents)
      end
    end
  end
end
