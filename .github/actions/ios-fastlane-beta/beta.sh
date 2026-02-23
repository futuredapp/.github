#!/bin/bash
set -e

# Change to iOS root for bundle install
if [ -n "$IOS_ROOT_PATH" ]; then
  echo "Installing gems from: $IOS_ROOT_PATH"
  cd $IOS_ROOT_PATH
fi

gem install bundler
bundle install --jobs 4 --retry 3

# Change to custom build directory for fastlane
if [ -n "$CUSTOM_BUILD_PATH" ]; then
  echo "Running fastlane from: $CUSTOM_BUILD_PATH"
  cd $GITHUB_WORKSPACE/$CUSTOM_BUILD_PATH
fi

# Build fastlane arguments from optional overrides
fastlane_args=()
[ -n "$BUILD_NUMBER" ] && fastlane_args+=("build_number:$BUILD_NUMBER")
[ -n "$VERSION_NUMBER" ] && fastlane_args+=("version_number:$VERSION_NUMBER")

# Environment variables are already set by action.yml
bundle exec fastlane beta "${fastlane_args[@]}"
