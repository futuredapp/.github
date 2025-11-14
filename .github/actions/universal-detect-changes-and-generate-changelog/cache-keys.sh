#!/bin/bash
set -e

# Store original prefix for debug output
ORIGINAL_CACHE_KEY_PREFIX="$CACHE_KEY_PREFIX"

# Generate cache key prefix based on input
if [ -n "$CACHE_KEY_PREFIX" ]; then
  CACHE_KEY_PREFIX="${CACHE_KEY_PREFIX}-latest_builded_commit-"
else
  CACHE_KEY_PREFIX="latest_builded_commit-"
fi

# Debug output if enabled
if [ "$DEBUG" == "true" ]; then
  echo "[DEBUG] CACHE_KEY_PREFIX='$ORIGINAL_CACHE_KEY_PREFIX'"
  echo "[DEBUG] CACHE_KEY_PREFIX='$CACHE_KEY_PREFIX'"
  echo "[DEBUG] CALCULATED_CACHE_KEY='$CACHE_KEY_PREFIX$GITHUB_SHA'"
fi

# Set outputs
echo "cache_key_prefix=$CACHE_KEY_PREFIX" >> $GITHUB_OUTPUT
