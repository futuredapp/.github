#!/bin/bash
set -e

MERGED_BRANCHES="$1"
COMPONENTS="$2"

# Extract JIRA keys from branches
JIRA_KEYS=()
if [[ -n "$MERGED_BRANCHES" ]]; then
  # Prevents globbing and word splitting issues
  IFS=',' read -ra BRANCHES <<< "$MERGED_BRANCHES"
  for branch in "${BRANCHES[@]}"; do
    # Trim leading/trailing whitespace from branch name
    branch=$(echo "$branch" | xargs)
    while IFS= read -r key; do
        JIRA_KEYS+=("$key")
    done < <(echo "$branch" | grep -oE '[A-Z]+-[0-9]+')
  done
fi

# Remove duplicate keys and create a space-separated string
UNIQUE_JIRA_KEYS_STR=$(echo "${JIRA_KEYS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)

# Build JQL query
JQL_PARTS=()
if [[ -n "$UNIQUE_JIRA_KEYS_STR" ]]; then
  # Convert space-separated keys to a comma-separated list for JQL
  KEYS_JQL="issueKey in ($(echo "$UNIQUE_JIRA_KEYS_STR" | sed 's/ /, /g'))"
  JQL_PARTS+=("$KEYS_JQL")
fi

if [[ -n "$COMPONENTS" ]]; then
  # Convert comma-separated components to a comma-and-space-separated list for JQL
  COMPONENTS_JQL="component in ($(echo "$COMPONENTS" | sed 's/,/, /g'))"
  JQL_PARTS+=("$COMPONENTS_JQL")
fi

# Join the JQL parts with " OR "
JQL=$(IFS=" OR "; echo "${JQL_PARTS[*]}")

# Set the output for the GitHub Action step
echo "jql=$JQL" >> "$GITHUB_OUTPUT"
