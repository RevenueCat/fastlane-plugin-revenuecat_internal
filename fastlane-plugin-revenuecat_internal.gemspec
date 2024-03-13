lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fastlane/plugin/revenuecat_internal/version'

Gem::Specification.new do |spec|
  spec.name          = 'fastlane-plugin-revenuecat_internal'
  spec.version       = Fastlane::RevenuecatInternal::VERSION
  spec.author        = 'Toni Rico'
  spec.email         = 'toni.rico.diez@revenuecat.com'

  spec.summary       = 'A plugin including commonly used automation logic for RevenueCat SDKs.'
  spec.homepage      = "https://github.com/RevenueCat/fastlane-plugin-revenuecat_internal"
  spec.license       = "MIT"

  spec.files         = Dir["lib/**/*"] + %w(README.md LICENSE)
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6'

  # Don't add a dependency to fastlane or fastlane_re
  # since this would cause a circular dependency

  spec.add_dependency('rest-client')

  spec.add_development_dependency('bundler')
  spec.add_development_dependency('fastlane', '2.207.0')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('rake')
  spec.add_development_dependency('rspec')
  spec.add_development_dependency('rspec_junit_formatter')
  spec.add_development_dependency('rubocop', '1.31.1')
  spec.add_development_dependency('rubocop-performance')
  spec.add_development_dependency('rubocop-rake')
  spec.add_development_dependency('rubocop-require_tools')
  spec.add_development_dependency('rubocop-rspec')
  spec.add_development_dependency('simplecov')
  spec.metadata['rubygems_mfa_required'] = 'true'
end
