require 'fastlane_core/ui/ui'

module Fastlane
  UI = FastlaneCore::UI unless Fastlane.const_defined?(:UI)

  module Helper
    class PollingHelper
      def self.wait_for_all(checks, where, timeout_seconds, poll_interval_seconds, soft_fail)
        deadline = Time.now + timeout_seconds

        checks.each do |description, available|
          next if wait_until(description, where, deadline, poll_interval_seconds, available)

          message = "#{description} still isn't on #{where} after #{timeout_seconds / 60}m."
          UI.user_error!("#{message} Giving up.") unless soft_fail
          UI.important("#{message} Continuing anyway.")
        end
      end

      def self.wait_until(description, where, deadline, poll_interval_seconds, available)
        loop do
          if available.call
            UI.success("#{description} is available on #{where}")
            return true
          end

          remaining = deadline - Time.now
          return false if remaining <= 0

          # Logged on every poll so CI sees output and doesn't hit an inactivity timeout.
          UI.message("Waiting for #{description} on #{where} (#{(remaining / 60).ceil}m remaining)...")
          sleep([poll_interval_seconds, remaining].min)
        end
      end
    end
  end
end
