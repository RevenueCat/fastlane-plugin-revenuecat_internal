# frozen_string_literal: true

REPO_NAME_IOS = 'purchases-ios'
REPO_NAME_ANDROID = 'purchases-android'
# Taken from https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
PATTERN_BUILD_METADATA = "[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*"
PATTERN_BUILD_METADATA_ANCHORED = /^#{PATTERN_BUILD_METADATA}$/.freeze
DELIMITER_PRERELEASE = '-'
DELIMITER_BUILD_METADATA = '+'
