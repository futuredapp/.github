#!/bin/bash
set -e

# Test runner script for the jira-transition-tickets action
# This script runs all unit tests using BATS (Bash Automated Testing System)

echo "🧪 Running unit tests for jira-transition-tickets action..."
echo ""

# Check if BATS is installed
if ! command -v bats &> /dev/null; then
    echo "❌ BATS is not installed. Please install it first:"
    echo "   macOS: brew install bats-core"
    echo "   Ubuntu/Debian: apt-get install bats"
    echo "   Or install from: https://github.com/bats-core/bats-core"
    exit 1
fi

# Run tests with verbose output
echo "Running extract-issue-keys tests..."
bats -v test_extract-issue-keys.bats

echo ""
echo "✅ All tests completed!"
