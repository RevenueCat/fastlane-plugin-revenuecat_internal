$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'simplecov'

# SimpleCov.minimum_coverage 95
SimpleCov.start

# This module is only used to check the environment is currently a testing env
module SpecHelper
end

require 'fastlane' # to import the Action super class
require 'fastlane/plugin/revenuecat_internal' # import the actual plugin

Fastlane.load_actions # load other actions (in case your plugin calls other actions or shared values)

require 'webmock/rspec'

WebMock.disable_net_connect!(allow_localhost: true)

# FastlaneCore::UI delegates methods (message, error, etc.) via method_missing,
# which means respond_to? returns false for them. This breaks RSpec's
# verify_partial_doubles since it checks respond_to? before allowing a mock.
# Defining respond_to_missing? makes these methods visible to verification
# while keeping the existing method_missing delegation for actual behavior.
FASTLANE_UI_DELEGATED_METHODS = %i[
  message important success error user_error! confirm interactive? input
  verbose header crash! abort_with_message! select command deprecated
].to_set.freeze

FastlaneCore::UI.define_singleton_method(:respond_to_missing?) do |method_name, include_private = false|
  FASTLANE_UI_DELEGATED_METHODS.include?(method_name) || super(method_name, include_private)
end

RSpec.configure do |config|
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end
