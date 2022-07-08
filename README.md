# revenuecat_internal plugin

[![fastlane Plugin Badge](https://rawcdn.githack.com/fastlane/fastlane/master/fastlane/assets/plugin-badge.svg)](https://rubygems.org/gems/fastlane-plugin-revenuecat_internal)

## Getting Started

This project is a [_fastlane_](https://github.com/fastlane/fastlane) plugin. To get started with `fastlane-plugin-revenuecat_internal`, add it to your project by running:

```bash
fastlane add_plugin revenuecat_internal
```

## About revenuecat_internal

A plugin including commonly used automation logic for RevenueCat SDKs.

### Actions

- `bump_version_update_changelog_create_pr`: This action asks for a new version number and updates all occurences of the old version number (passed as a parameter) in the list of files to update (also passed as a parameter). It also fetches the list of commits since the last tag in the given repo and generates a changelog using those, allowing the user to edit the result. Finally, it creates a release branch in the form of `release/NEW_VERSION_NUMBER`, commits and pushes all changes to `origin` and creates a release PR.
- `replace_version_number`: This action asks for a new version number and updates all occurences of the old version number (passed as a parameter) in the list of files to update (also passed as a parameter).
- `create_next_snapshot_version`: This action creates bumps the version to the next minor with a `-SNAPSHOT` suffix and creates a PR with the changes.

## Example

Check out the [example `Fastfile`](fastlane/Fastfile) to see how to use this plugin. Try it by cloning the repo, running `fastlane install_plugins` and `bundle exec fastlane test`.

## Run tests for this plugin

To run both the tests, and code style validation, run

```
rake
```

To automatically fix many of the styling issues, use
```
rubocop -a
```

## Issues and Feedback

For any other issues and feedback about this plugin, please submit it to this repository.

## Troubleshooting

If you have trouble using plugins, check out the [Plugins Troubleshooting](https://docs.fastlane.tools/plugins/plugins-troubleshooting/) guide.

## Using _fastlane_ Plugins

For more information about how the `fastlane` plugin system works, check out the [Plugins documentation](https://docs.fastlane.tools/plugins/create-plugin/).

## About _fastlane_

_fastlane_ is the easiest way to automate beta deployments and releases for your iOS and Android apps. To learn more, check out [fastlane.tools](https://fastlane.tools).
