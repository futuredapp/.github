#!/bin/bash
# set -e  # Disabled to handle git errors gracefully

# Global variables
FROM_COMMIT="$FROM_COMMIT"
TO_COMMIT="$TO_COMMIT"
FORMATTED_CHANGELOG=""
FORMATTED_BRANCH_NAMES=""

# Debug logging function
debug_log() {
  if [ "$DEBUG" == "true" ]; then
    echo "[DEBUG] $1"
  fi
}

# Get git log for changelog (commit messages)
get_changelog() {
  local from_commit="$1"
  local to_commit="$2"
  
  if [ "$from_commit" == "$to_commit" ]; then
    debug_log "FROM_COMMIT is same as HEAD. Using range HEAD~1..HEAD"
    git log --merges --first-parent --pretty=format:"%b" HEAD~1..HEAD 2>&1
    return $?
  else
    debug_log "Using range ${from_commit}..${to_commit}"
    git log --merges --first-parent --pretty=format:"%b" "${from_commit}..${to_commit}" 2>&1
    return $?
  fi
}

# Get git log for branch names (commit subjects)
get_branch_names() {
  local from_commit="$1"
  local to_commit="$2"
  
  if [ "$from_commit" == "$to_commit" ]; then
    git log --merges --first-parent --pretty=format:"%s" HEAD~1..HEAD | \
      sed -e "s/^Merge branch '//" -e "s/^Merge pull request .* from //" -e "s/' into.*$//" -e "s/ into.*$//" | \
      grep -v '^$' 2>&1 || true
    return 0
  else
    git log --merges --first-parent --pretty=format:"%s" "${from_commit}..${to_commit}" | \
      sed -e "s/^Merge branch '//" -e "s/^Merge pull request .* from //" -e "s/' into.*$//" -e "s/ into.*$//" | \
      grep -v '^$' 2>&1 || true
    return 0
  fi
}

# Check if string is empty (after removing whitespace)
is_empty() {
  local text="$1"
  [ -z "$(echo "$text" | tr -d '\n\r \t')" ]
}

# Format changelog text
format_changelog() {
  local raw_changelog="$1"
  echo "$raw_changelog" | grep -v '^$' | paste -sd, - | \
    sed 's/,/, /g' | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

# Format branch names
format_branch_names() {
  local raw_branch_names="$1"
  if [ -n "$raw_branch_names" ]; then
    echo "$raw_branch_names" | sort -u | paste -sd, - | \
      sed 's/,/, /g' | \
      sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
  fi
}

# Handle git log failure
handle_git_failure() {
  local exit_code="$1"
  local output="$2"
  echo "##[WARNING] Git log command failed with exit code $exit_code. Output: $output"
  FORMATTED_CHANGELOG="Error generating changelog: command failed."
}

# Handle empty changelog
handle_empty_changelog() {
  debug_log "Raw changelog is empty. Setting default message."
  FORMATTED_CHANGELOG="No changelog provided."
}

# Process successful git log results
process_successful_log() {
  local raw_changelog="$1"
  local raw_branch_names="$2"
  
  FORMATTED_CHANGELOG=$(format_changelog "$raw_changelog")
  FORMATTED_BRANCH_NAMES=$(format_branch_names "$raw_branch_names")
}

# Escape output for GitHub Actions
escape_output() {
  local text="$1"
  echo "$text" | sed 's/%/%25/g' | sed 's/\n/%0A/g' | sed 's/\r/%0D/g'
}

# Set GitHub outputs
set_outputs() {
  local changelog_output=$(escape_output "$FORMATTED_CHANGELOG")
  local branches_output=$(escape_output "$FORMATTED_BRANCH_NAMES")
  
  echo "changelog_string=${changelog_output}" >> $GITHUB_OUTPUT
  echo "merged_branches=${branches_output}" >> $GITHUB_OUTPUT
}

# Debug output function
debug_outputs() {
  if [ "$DEBUG" == "true" ]; then
    echo "[DEBUG] Generated raw changelog:"
    echo "$1"
    echo "[DEBUG] Generated raw branch names:"
    echo "$2"
    echo "[DEBUG] Formatted changelog for output:"
    echo "$FORMATTED_CHANGELOG"
    echo "[DEBUG] Formatted branch names for output:"
    echo "$FORMATTED_BRANCH_NAMES"
  fi
}

# Main execution
main() {
  debug_log "Generating changelog from $FROM_COMMIT to $TO_COMMIT"
  
  # Get raw data from git directly (not through functions to preserve exit codes)
  local raw_changelog
  local raw_branch_names
  local git_exit_code=0
  
  if [ "$FROM_COMMIT" == "$TO_COMMIT" ]; then
    debug_log "FROM_COMMIT is same as HEAD. Using range HEAD~1..HEAD"
    raw_changelog=$(git log --merges --first-parent --pretty=format:"%b" HEAD~1..HEAD 2>&1)
    git_exit_code=$?
    
    if [ $git_exit_code -eq 0 ]; then
      raw_branch_names=$(git log --merges --first-parent --pretty=format:"%s" HEAD~1..HEAD 2>&1 | \
        sed -e "s/^Merge branch '//" -e "s/^Merge pull request .* from //" -e "s/' into.*$//" -e "s/ into.*$//" | \
        grep -v '^$' 2>&1 || true)
      git_exit_code=0
    else
      raw_branch_names=""
    fi
  else
    debug_log "Using range ${FROM_COMMIT}..${TO_COMMIT}"
    raw_changelog=$(git log --merges --first-parent --pretty=format:"%b" "${FROM_COMMIT}..${TO_COMMIT}" 2>&1)
    git_exit_code=$?
    
    if [ $git_exit_code -eq 0 ]; then
      raw_branch_names=$(git log --merges --first-parent --pretty=format:"%s" "${FROM_COMMIT}..${TO_COMMIT}" 2>&1 | \
        sed -e "s/^Merge branch '//" -e "s/^Merge pull request .* from //" -e "s/' into.*$//" -e "s/ into.*$//" | \
        grep -v '^$' 2>&1 || true)
      git_exit_code=0
    else
      raw_branch_names=""
    fi
  fi
  
  # Process results based on git command success
  if [ $git_exit_code -ne 0 ] && [ -n "$raw_changelog" ]; then
    # Git error with actual error message
    handle_git_failure $git_exit_code "$raw_changelog"
  elif is_empty "$raw_changelog"; then
    # Empty result (either no commits or git error with no output)
    handle_empty_changelog
  else
    # Successful result
    process_successful_log "$raw_changelog" "$raw_branch_names"
  fi
  
  debug_outputs "$raw_changelog" "$raw_branch_names"
  set_outputs
}

# Run main function
main
