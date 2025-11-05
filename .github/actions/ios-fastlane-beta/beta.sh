#!/bin/bash
set -e

# Change to custom build path first if specified
if [ -n "$CUSTOM_BUILD_PATH" ]; then
  cd $CUSTOM_BUILD_PATH
fi

gem install bundler
bundle install --jobs 4 --retry 3

# Environment variables are already set by action.yml
# No need to re-export them

bundle exec fastlane beta
