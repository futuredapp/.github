#!/bin/bash
set -e

# Initialize variables
LASTEST_BUILD_COMMIT=""
CURRENT_HEAD_SHA=$(git rev-parse HEAD)
FROM_COMMIT=""
TO_COMMIT="$CURRENT_HEAD_SHA"
BUILD_SHOULD_SKIP="false"

# Check if we have a previous build commit from cache
if [ -f latest_builded_commit.txt ]; then
  LASTEST_BUILD_COMMIT=$(< latest_builded_commit.txt)
fi

if [ "$INPUT_DEBUG" == "true" ]; then 
  echo "[DEBUG] Previous built commit SHA from cache: '$LASTEST_BUILD_COMMIT'"
fi

# Validate previous build commit if it exists
if [ -n "$LASTEST_BUILD_COMMIT" ]; then
  # Check if the commit exists in history, otherwise it might have been rebased
  if ! git cat-file -e $LASTEST_BUILD_COMMIT 2>/dev/null; then
    echo "[WARNING] Last build commit '$LASTEST_BUILD_COMMIT' not found in history. Will look for oldest commit in last $INPUT_FALLBACK_LOOKBACK."
    LASTEST_BUILD_COMMIT="" # Reset to fall through to the next block
  fi
fi

if [ -n "$LASTEST_BUILD_COMMIT" ]; then
  # Happy path: previous build commit exists and is valid
  if [ "$INPUT_DEBUG" == "true" ]; then 
    echo "[DEBUG] Using git range: '$LASTEST_BUILD_COMMIT..HEAD'"
  fi
  
  MERGE_COMMITS_EXIST=$(git rev-list --merges --first-parent --count $LASTEST_BUILD_COMMIT..HEAD)

  if [ "$MERGE_COMMITS_EXIST" -gt 0 ]; then
    if [ "$INPUT_DEBUG" == "true" ]; then 
      echo "[DEBUG] New merge commits found since last build. Proceeding with build."
    fi
    FROM_COMMIT="$LASTEST_BUILD_COMMIT"
  else
    if [ "$INPUT_DEBUG" == "true" ]; then 
      echo "[DEBUG] No new merge commits found since last build. Skipping build."
    fi
    BUILD_SHOULD_SKIP="true"
  fi
else
  # Case 2: No last built commit or it was invalid
  # Find the oldest merge commit in the specified time window
  if [ "$INPUT_DEBUG" == "true" ]; then 
    echo "[DEBUG] No previous built commit or it was invalid, looking for oldest merge commit in last $INPUT_FALLBACK_LOOKBACK."
  fi
  
  OLDEST_MERGE_COMMIT=$(git rev-list --merges --first-parent --reverse --after="$INPUT_FALLBACK_LOOKBACK" --max-count=1 HEAD | head -n 1)

  if [ -n "$OLDEST_MERGE_COMMIT" ]; then
    if [ "$INPUT_DEBUG" == "true" ]; then 
      echo "[DEBUG] Oldest merge commit in last $INPUT_FALLBACK_LOOKBACK found. Proceeding with build."
    fi
    FROM_COMMIT="$OLDEST_MERGE_COMMIT^"
  else
    if [ "$INPUT_DEBUG" == "true" ]; then 
      echo "[DEBUG] No merge commits found in the last $INPUT_FALLBACK_LOOKBACK. Skipping build."
    fi
    BUILD_SHOULD_SKIP="true"
  fi
fi

# Set outputs
if [ "$BUILD_SHOULD_SKIP" == "true" ]; then
  echo "build_should_skip=true" >> $GITHUB_OUTPUT
else
  echo "build_should_skip=false" >> $GITHUB_OUTPUT
  echo "from_commit=$FROM_COMMIT" >> $GITHUB_OUTPUT
  echo "to_commit=$TO_COMMIT" >> $GITHUB_OUTPUT
fi

# Debug output
if [ "$INPUT_DEBUG" == "true" ]; then
  echo "[DEBUG] build_should_skip output: $(grep '^build_should_skip=' $GITHUB_OUTPUT | cut -d= -f2)"
  echo "[DEBUG] from_commit output: $(grep '^from_commit=' $GITHUB_OUTPUT | cut -d= -f2)"
  echo "[DEBUG] to_commit output: $(grep '^to_commit=' $GITHUB_OUTPUT | cut -d= -f2)"
fi
