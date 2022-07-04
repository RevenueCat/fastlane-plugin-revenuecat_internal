require 'fastlane_core/ui/ui'
require 'fastlane/action'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class RevenuecatHelper
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
