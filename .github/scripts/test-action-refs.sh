#!/bin/bash
# Tests for find, bump, and validate action ref scripts.
#
# Usage: .github/scripts/test-action-refs.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
passed=0
failed=0

assert_exit() {
    local expected=$1 description=$2
    shift 2
    if "$@" >/dev/null 2>&1; then actual=0; else actual=$?; fi
    if [ "$actual" -eq "$expected" ]; then
        echo "  PASS: $description"
        passed=$((passed + 1))
    else
        echo "  FAIL: $description (expected exit $expected, got $actual)"
        failed=$((failed + 1))
    fi
}

echo "=== find-action-refs ==="
file_count=$("$SCRIPT_DIR/find-action-refs.sh" | wc -l | tr -d ' ')
if [ "$file_count" -gt 0 ]; then
    echo "  PASS: Found $file_count files with action refs"
    passed=$((passed + 1))
else
    echo "  FAIL: No files found"
    failed=$((failed + 1))
fi

echo ""
echo "=== bump + validate ==="

# Bump to a test version
"$SCRIPT_DIR/bump-action-refs.sh" 8.8.8 >/dev/null
assert_exit 0 "Validate passes after bump to 8.8.8" "$SCRIPT_DIR/validate-action-refs.sh" 8.8.8
assert_exit 1 "Validate fails for wrong version 9.9.9" "$SCRIPT_DIR/validate-action-refs.sh" 9.9.9

# Bump to another version
"$SCRIPT_DIR/bump-action-refs.sh" 1.0.0 >/dev/null
assert_exit 0 "Validate passes after bump to 1.0.0" "$SCRIPT_DIR/validate-action-refs.sh" 1.0.0
assert_exit 1 "Validate fails for old version 8.8.8" "$SCRIPT_DIR/validate-action-refs.sh" 8.8.8

# Revert to main
"$SCRIPT_DIR/bump-action-refs.sh" main >/dev/null
assert_exit 0 "Validate passes after revert to main" "$SCRIPT_DIR/validate-action-refs.sh" main
assert_exit 1 "Validate fails for version after revert" "$SCRIPT_DIR/validate-action-refs.sh" 1.0.0

echo ""
echo "=== Results: $passed passed, $failed failed ==="
[ "$failed" -eq 0 ]
