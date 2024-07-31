# frozen_string_literal: true

REPO_NAME_IOS = 'purchases-ios'
REPO_NAME_ANDROID = 'purchases-android'
# Taken from https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
BUILD_METADATA_PATTERN = "[0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*"
ANCHORED_BUILD_METADATA_PATTERN = /^#{BUILD_METADATA_PATTERN}$/.freeze
