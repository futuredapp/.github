#!/bin/bash
set -e

gem install bundler
bundle install --jobs 4 --retry 3

# Environment variables are already set by action.yml
# No need to re-export them
if [ -n "$CUSTOM_BUILD_PATH" ]; then
  cd $CUSTOM_BUILD_PATH
fi

bundle exec fastlane beta
