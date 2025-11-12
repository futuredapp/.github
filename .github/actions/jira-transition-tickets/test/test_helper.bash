#!/usr/bin/env bash

# Test helper functions for BATS tests

# Create a temporary GITHUB_OUTPUT file for testing
setup() {
  export GITHUB_OUTPUT=$(mktemp)
}

# Clean up temporary files
teardown() {
  rm -f "$GITHUB_OUTPUT"
}