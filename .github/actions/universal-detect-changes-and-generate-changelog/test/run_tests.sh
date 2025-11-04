#!/bin/bash
set -e

# Test runner script for the universal-detect-changes-and-generate-changelog action
# This script runs all unit tests using BATS (Bash Automated Testing System)

echo "🧪 Running unit tests for universal-detect-changes-and-generate-changelog action..."
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
echo "Running cache-keys tests..."
bats -v test_cache-keys.bats

echo ""
echo "Running determine-range tests..."
bats -v test_determine-range.bats

echo ""
echo "Running generate-changelog tests..."
bats -v test_generate-changelog.bats

echo ""
echo "✅ All tests completed!"
