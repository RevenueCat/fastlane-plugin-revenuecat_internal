require 'set'

# Scans action source files for calls to Helper classes and verifies that each
# called method actually exists on the corresponding helper. This catches method
# renames or typos in action implementations that unit tests miss because mocks
# don't execute the real code path.
#
# Complements verify_partial_doubles (which catches test-side mock mismatches)
# by covering the implementation side.
HELPER_CLASSES = {
  'GitHubHelper' => Fastlane::Helper::GitHubHelper,
  'RevenuecatInternalHelper' => Fastlane::Helper::RevenuecatInternalHelper,
  'VersioningHelper' => Fastlane::Helper::VersioningHelper,
  'UpdateHybridsVersionsFileHelper' => Fastlane::Helper::UpdateHybridsVersionsFileHelper,
  'MavenCentralHelper' => Fastlane::Helper::MavenCentralHelper
}.freeze

describe 'Helper method contracts' do
  actions_dir = File.expand_path('../../lib/fastlane/plugin/revenuecat_internal/actions', __dir__)

  Dir[File.join(actions_dir, '*.rb')].each do |action_file|
    action_basename = File.basename(action_file, '.rb')
    source = File.read(action_file)

    HELPER_CLASSES.each do |helper_name, helper_class|
      called_methods = source.scan(/Helper::#{helper_name}\.(\w+[?!]?)/).flatten.uniq
      next if called_methods.empty?

      helper_methods = helper_class.methods(false).map(&:to_s).to_set

      describe "#{action_basename} -> #{helper_name}" do
        called_methods.each do |method_name|
          it "calls .#{method_name} which exists" do
            expect(helper_methods).to(
              include(method_name),
              "#{action_basename} calls #{helper_name}.#{method_name} but that method does not exist. " \
              "Available public methods: #{helper_methods.sort.join(', ')}"
            )
          end
        end
      end
    end
  end
end
