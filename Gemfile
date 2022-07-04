source('https://rubygems.org')

gemspec

gem "fastlane", "2.191.0"
gem 'rubocop', '1.31.1'

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
