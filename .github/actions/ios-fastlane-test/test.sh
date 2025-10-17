#!/bin/bash
set -e

cd iosApp
gem install bundler
bundle install --jobs 4 --retry 3

export DANGER_GITHUB_API_TOKEN="$INPUT_GITHUB_TOKEN"
export CUSTOM_VALUES="$INPUT_CUSTOM_VALUES"

bundle exec fastlane test
