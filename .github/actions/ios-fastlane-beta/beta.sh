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

# Environment variables are already set by action.yml
bundle exec fastlane beta
