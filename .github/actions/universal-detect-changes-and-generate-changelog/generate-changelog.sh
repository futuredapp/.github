#!/bin/bash
set -e

FROM_COMMIT="$INPUT_FROM_COMMIT"
TO_COMMIT="$INPUT_TO_COMMIT"

if [ "$INPUT_DEBUG" == "true" ]; then
  echo "[DEBUG] Generating changelog from $FROM_COMMIT to $TO_COMMIT"
fi

# Get changelog between FROM_COMMIT and TO_COMMIT
# Special case for same commit range
if [ "$FROM_COMMIT" == "$TO_COMMIT" ]; then
  if [ "$INPUT_DEBUG" == "true" ]; then 
    echo "[DEBUG] FROM_COMMIT is same as HEAD. Using range HEAD~1..HEAD"
  fi
  CHANGELOG=$(git log --merges --first-parent --pretty=format:"%b" HEAD~1..HEAD 2>&1)
  BRANCH_NAMES=$(git log --merges --first-parent --pretty=format:"%s" HEAD~1..HEAD | sed -e "s/^Merge branch '//" -e "s/^Merge pull request .* from //" -e "s/' into.*$//" -e "s/ into.*$//" | grep -v '^$' 2>&1)
  GIT_LOG_EXIT_CODE=$?
else
  if [ "$INPUT_DEBUG" == "true" ]; then 
    echo "[DEBUG] Using range ${FROM_COMMIT}..${TO_COMMIT}"
  fi
  CHANGELOG=$(git log --merges --first-parent --pretty=format:"%b" ${FROM_COMMIT}..${TO_COMMIT} 2>&1)
  BRANCH_NAMES=$(git log --merges --first-parent --pretty=format:"%s" ${FROM_COMMIT}..${TO_COMMIT} | sed -e "s/^Merge branch '//" -e "s/^Merge pull request .* from //" -e "s/' into.*$//" -e "s/ into.*$//" | grep -v '^$' 2>&1)
  GIT_LOG_EXIT_CODE=$?
fi

# Initialize variables
FORMATTED_CHANGELOG=""
FORMATTED_BRANCH_NAMES=""

# Check if git log command actually failed (exit code non-zero)
if [ $GIT_LOG_EXIT_CODE -ne 0 ]; then
  echo "##[WARNING] Git log command failed with exit code $GIT_LOG_EXIT_CODE. Output: $CHANGELOG"
  FORMATTED_CHANGELOG="Error generating changelog: command failed."
elif [ -z "$(echo "$CHANGELOG" | tr -d '\n\r')" ]; then # Check if CHANGELOG is empty (after removing whitespace)
  if [ "$INPUT_DEBUG" == "true" ]; then 
    echo "[DEBUG] Raw changelog is empty. Setting default message."
  fi
  FORMATTED_CHANGELOG="No changelog provided."
else
  # Format changelog
  FORMATTED_CHANGELOG=$(echo "$CHANGELOG" | grep -v '^$' | paste -sd, -)
  FORMATTED_CHANGELOG=$(echo "$FORMATTED_CHANGELOG" | sed 's/,/, /g') # Add space after comma
  FORMATTED_CHANGELOG="$(echo "$FORMATTED_CHANGELOG" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  # Format branch names
  if [ -n "$BRANCH_NAMES" ]; then
    FORMATTED_BRANCH_NAMES=$(echo "$BRANCH_NAMES" | sort -u | paste -sd, -)
    FORMATTED_BRANCH_NAMES=$(echo "$FORMATTED_BRANCH_NAMES" | sed 's/,/, /g') # Add space after comma
    FORMATTED_BRANCH_NAMES="$(echo "$FORMATTED_BRANCH_NAMES" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  fi
fi

if [ "$INPUT_DEBUG" == "true" ]; then
  echo "[DEBUG] Generated raw changelog:"
  echo "$CHANGELOG"
  echo "[DEBUG] Generated raw branch names:"
  echo "$BRANCH_NAMES"
  echo "[DEBUG] Formatted changelog for output:"
  echo "$FORMATTED_CHANGELOG"
  echo "[DEBUG] Formatted branch names for output:"
  echo "$FORMATTED_BRANCH_NAMES"
fi

# Set step outputs for the formatted strings
# Use delimited string for multi-line outputs
CHANGELOG_STRING_OUTPUT=$(echo "$FORMATTED_CHANGELOG" | sed 's/%/%25/g' | sed 's/\n/%0A/g' | sed 's/\r/%0D/g')
BRANCH_NAMES_OUTPUT=$(echo "$FORMATTED_BRANCH_NAMES" | sed 's/%/%25/g' | sed 's/\n/%0A/g' | sed 's/\r/%0D/g')
echo "changelog_string=${CHANGELOG_STRING_OUTPUT}" >> $GITHUB_OUTPUT
echo "merged_branches=${BRANCH_NAMES_OUTPUT}" >> $GITHUB_OUTPUT
