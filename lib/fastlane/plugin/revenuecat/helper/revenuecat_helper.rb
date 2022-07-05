require 'fastlane_core/ui/ui'
require 'fastlane/action'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class RevenuecatHelper
      def self.replace_version_number(previous_version_number, new_version_number, files_to_update, files_to_update_without_prerelease_modifiers)
        previous_version_number_without_prerelease_modifiers = previous_version_number.split("-")[0]
        new_version_number_without_prerelease_modifiers = new_version_number.split("-")[0]

        files_to_update.each do |file_to_update|
          replace_in(previous_version_number, new_version_number, file_to_update)
        end
        files_to_update_without_prerelease_modifiers.each do |file_to_update|
          replace_in(previous_version_number_without_prerelease_modifiers, new_version_number_without_prerelease_modifiers, file_to_update)
        end
      end

      def self.replace_in(previous_text, new_text, path, allow_empty: false)
        if new_text.to_s.strip.empty? && !allow_empty
          UI.user_error!("Missing `new_text` in call to `replace_in`, looking for replacement for #{previous_text} 😵.")
        end
        sed_regex = "s|#{previous_text.sub('.', '\\.')}|#{new_text}|"
        backup_extension = '.bck'
        Action.sh("sed", '-i', backup_extension, sed_regex, path)
      end
    end
  end
end
