#!/bin/bash
set -e

# Generate cache key prefix based on input
if [ -n "$INPUT_CACHE_KEY_PREFIX" ]; then
  CACHE_KEY_PREFIX="${INPUT_CACHE_KEY_PREFIX}-latest_builded_commit-"
else
  CACHE_KEY_PREFIX="latest_builded_commit-"
fi

# Debug output if enabled
if [ "$INPUT_DEBUG" == "true" ]; then 
  echo "[DEBUG] INPUT_CACHE_KEY_PREFIX='$INPUT_CACHE_KEY_PREFIX'"
  echo "[DEBUG] CACHE_KEY_PREFIX='$CACHE_KEY_PREFIX'"
  echo "[DEBUG] CALCULATED_CACHE_KEY='$CACHE_KEY_PREFIX$GITHUB_SHA'"
fi

# Set outputs
echo "cache_key_prefix=$CACHE_KEY_PREFIX" >> $GITHUB_OUTPUT
