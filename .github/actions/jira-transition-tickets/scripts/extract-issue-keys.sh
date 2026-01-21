#!/bin/bash
set -e

MERGED_BRANCHES="$1"

# Extract JIRA keys from branches
JIRA_KEYS=()
if [[ -n "$MERGED_BRANCHES" ]]; then
  # Prevents globbing and word splitting issues
  IFS=',' read -ra BRANCHES <<< "$MERGED_BRANCHES"
  for branch in "${BRANCHES[@]}"; do
    # Trim leading/trailing whitespace from branch name
    branch="${branch#"${branch%%[![:space:]]*}"}"
    branch="${branch%"${branch##*[![:space:]]}"}"
    while IFS= read -r key; do
        JIRA_KEYS+=("$key")
    done < <(echo "$branch" | grep -oE '[A-Z0-9]+-[0-9]+')
  done
fi

# Remove duplicate keys and create a space-separated string
UNIQUE_JIRA_KEYS_STR=$(echo "${JIRA_KEYS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

# Build issue keys list
ISSUE_KEYS=""
if [[ -n "$UNIQUE_JIRA_KEYS_STR" ]]; then
  ISSUE_KEYS="${UNIQUE_JIRA_KEYS_STR// /,}"
fi

# Set the output for the GitHub Action step
echo "issue_keys=$ISSUE_KEYS" >> "$GITHUB_OUTPUT"
