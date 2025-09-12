# frozen_string_literal: true

REPO_NAME_IOS = 'purchases-ios'
REPO_NAME_ANDROID = 'purchases-android'
# Taken from https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
PATTERN_BUILD_METADATA = "[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*"
PATTERN_BUILD_METADATA_ANCHORED = /^#{PATTERN_BUILD_METADATA}$/.freeze
DELIMITER_PRERELEASE = '-'
DELIMITER_BUILD_METADATA = '+'

SDK_WARNING_VERSIONS = {
  'purchases-unity' => '8.0.0',
  'purchases-android' => '9.0.0',
  'purchases-flutter' => '9.0.0',
  'react-native-purchases' => '9.0.0',
  'purchases-capacitor' => '11.0.0',
  'cordova-plugin-purchases' => '7.0.0',
  'purchases-kmp' => '2.0.0'
}.freeze

OTP_WARNING_TEXT = <<~WARNING
  > [!WARNING]  
  > If you don't have any login system in your app, please make sure your one-time purchase products have been correctly configured in the RevenueCat dashboard as either consumable or non-consumable. If they're incorrectly configured as consumables, RevenueCat will consume these purchases. This means that users won't be able to restore them from version %{version} onward.
  > Non-consumables are products that are meant to be bought only once, for example, lifetime subscriptions.
WARNING
