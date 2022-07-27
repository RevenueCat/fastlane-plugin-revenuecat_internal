require 'bundler/gem_tasks'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

# Not using RuboCop::RakeTask.new(:rubocop) since it's showing different errors than just running rubocop
task :rubocop do
  sh 'rubocop'
end

task(default: [:spec, :rubocop])
