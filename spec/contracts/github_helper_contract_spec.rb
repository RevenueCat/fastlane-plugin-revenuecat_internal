require 'set'

# Verifies that action classes only call methods that actually exist on GitHubHelper.
# This catches method renames that unit tests miss because RSpec mocks don't verify
# that stubbed methods exist on the real class (verify_partial_doubles can't be
# enabled globally due to FastlaneCore::UI using method_missing delegation).
describe 'GitHubHelper method contract' do
  helper_methods = Fastlane::Helper::GitHubHelper.methods(false).map(&:to_s).to_set

  actions_dir = File.expand_path('../../lib/fastlane/plugin/revenuecat_internal/actions', __dir__)

  Dir[File.join(actions_dir, '*.rb')].each do |action_file|
    action_basename = File.basename(action_file, '.rb')
    source = File.read(action_file)
    called_methods = source.scan(/Helper::GitHubHelper\.(\w+[?!]?)/).flatten.uniq

    next if called_methods.empty?

    describe action_basename do
      called_methods.each do |method_name|
        it "calls GitHubHelper.#{method_name} which exists" do
          expect(helper_methods).to include(method_name),
            "#{action_basename} calls GitHubHelper.#{method_name} but that method does not exist. " \
            "Available public methods: #{helper_methods.sort.join(', ')}"
        end
      end
    end
  end
end
