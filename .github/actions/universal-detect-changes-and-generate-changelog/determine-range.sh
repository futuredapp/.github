#!/bin/bash
set -e

# Global variables
CURRENT_HEAD_SHA=$(git rev-parse HEAD)
FROM_COMMIT=""
TO_COMMIT="$CURRENT_HEAD_SHA"
BUILD_SHOULD_SKIP="false"

# Debug logging function
debug_log() {
  if [ "$INPUT_DEBUG" == "true" ]; then
    echo "[DEBUG] $1"
  fi
}

# Load previous build commit from cache
load_previous_build_commit() {
  if [ -f latest_builded_commit.txt ]; then
    cat latest_builded_commit.txt
  else
    echo ""
  fi
}

# Validate if commit exists in git history
is_commit_valid() {
  local commit_sha="$1"
  git cat-file -e "$commit_sha" 2>/dev/null
}

# Check if there are merge commits since given commit
has_merge_commits_since() {
  local from_commit="$1"
  local count=$(git rev-list --merges --first-parent --count "$from_commit..HEAD")
  [ "$count" -gt 0 ]
}

# Find oldest merge commit in time window
find_oldest_merge_commit() {
  local time_window="$1"
  git rev-list --merges --first-parent --reverse --after="$time_window" --max-count=1 HEAD | head -n 1
}

# Handle case when we have a valid previous build commit
handle_valid_previous_commit() {
  local last_commit="$1"
  debug_log "Using git range: '$last_commit..HEAD'"
  
  if has_merge_commits_since "$last_commit"; then
    debug_log "New merge commits found since last build. Proceeding with build."
    FROM_COMMIT="$last_commit"
  else
    debug_log "No new merge commits found since last build. Skipping build."
    BUILD_SHOULD_SKIP="true"
  fi
}

# Handle case when we need to use fallback logic
handle_fallback_commit() {
  debug_log "No previous built commit or it was invalid, looking for oldest merge commit in last $INPUT_FALLBACK_LOOKBACK."
  
  local oldest_commit=$(find_oldest_merge_commit "$INPUT_FALLBACK_LOOKBACK")
  
  if [ -n "$oldest_commit" ]; then
    debug_log "Oldest merge commit in last $INPUT_FALLBACK_LOOKBACK found. Proceeding with build."
    FROM_COMMIT="${oldest_commit}^"
  else
    debug_log "No merge commits found in the last $INPUT_FALLBACK_LOOKBACK. Skipping build."
    BUILD_SHOULD_SKIP="true"
  fi
}

# Set GitHub outputs
set_outputs() {
  if [ "$BUILD_SHOULD_SKIP" == "true" ]; then
    echo "build_should_skip=true" >> $GITHUB_OUTPUT
  else
    echo "build_should_skip=false" >> $GITHUB_OUTPUT
    echo "from_commit=$FROM_COMMIT" >> $GITHUB_OUTPUT
    echo "to_commit=$TO_COMMIT" >> $GITHUB_OUTPUT
  fi
}

# Debug output function
debug_outputs() {
  if [ "$INPUT_DEBUG" == "true" ]; then
    echo "[DEBUG] build_should_skip output: $(grep '^build_should_skip=' $GITHUB_OUTPUT | cut -d= -f2)"
    echo "[DEBUG] from_commit output: $(grep '^from_commit=' $GITHUB_OUTPUT | cut -d= -f2)"
    echo "[DEBUG] to_commit output: $(grep '^to_commit=' $GITHUB_OUTPUT | cut -d= -f2)"
  fi
}

# Main execution
main() {
  local last_build_commit=$(load_previous_build_commit)
  debug_log "Previous built commit SHA from cache: '$last_build_commit'"
  
  # Validate previous build commit if it exists
  if [ -n "$last_build_commit" ] && is_commit_valid "$last_build_commit"; then
    handle_valid_previous_commit "$last_build_commit"
  else
    if [ -n "$last_build_commit" ]; then
      echo "[WARNING] Last build commit '$last_build_commit' not found in history. Will look for oldest commit in last $INPUT_FALLBACK_LOOKBACK."
    fi
    handle_fallback_commit
  fi
  
  set_outputs
  debug_outputs
}

# Run main function
main
