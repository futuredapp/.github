#!/bin/bash
set -e

gem install bundler
bundle install --jobs 4 --retry 3

# Environment variables are already set by action.yml
# No need to re-export them

bundle exec fastlane test
