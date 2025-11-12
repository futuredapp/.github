#!/bin/bash
set -e

JIRA_CONTEXT="$1"
TRANSITION_NAME="$2"
ISSUE_KEYS="$3"

# Decode and parse JIRA_CONTEXT
JIRA_CONTEXT_JSON=$(echo "$JIRA_CONTEXT" | base64 --decode)
JIRA_BASE_URL=$(echo "$JIRA_CONTEXT_JSON" | jq -r '.base_url')
JIRA_USER_EMAIL=$(echo "$JIRA_CONTEXT_JSON" | jq -r '.user_email')
JIRA_API_TOKEN=$(echo "$JIRA_CONTEXT_JSON" | jq -r '.api_token')

if [[ -z "$ISSUE_KEYS" ]]; then
  echo "No issue keys provided. Skipping transition."
  exit 0
fi

# TODO implement this 👇
# For each issue key, call GET /rest/api/3/issue/{issueIdOrKey}/transitions (https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-transitions-get)
# and find a transition id by matching its name $TRANSITION_NAME.
# Then call POST /rest/api/3/issue/{issueIdOrKey}/transitions (https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issues/#api-rest-api-3-issue-issueidorkey-transitions-post)
# with request body "{ "transition": { "id": $TRANSITION_ID } }"

# URL encode the JQL query to handle special characters
ENCODED_JQL=$(perl -MURI::Escape -e 'print uri_escape($ARGV[0]);' "$JQL")

# Get all issues that match the JQL, including their transitions
ISSUES_URL="${JIRA_BASE_URL}/rest/api/3/search?jql=${ENCODED_JQL}&fields=id,transitions"

API_RESPONSE=$(curl -s -u "${JIRA_USER_EMAIL}:${JIRA_API_TOKEN}" \
  -X GET -H "Content-Type: application/json" \
  "$ISSUES_URL")

# Check if the API returned any errors
if echo "$API_RESPONSE" | jq -e '.errorMessages' > /dev/null; then
  echo "Error searching for issues:"
  echo "$API_RESPONSE" | jq .
  exit 1
fi

# Loop through each issue found and transition it
for issue_id in $(echo "$API_RESPONSE" | jq -r '.issues[].id'); do
  echo "Processing issue ID: $issue_id"

  # Find the correct transition ID for this specific issue
  TRANSITION_ID=$(echo "$API_RESPONSE" | \
    jq -r --arg id "$issue_id" --arg status "$TARGET_STATUS" \
    '.issues[] | select(.id == $id) | .transitions[] | select(.name == $status) | .id')

  if [[ -z "$TRANSITION_ID" || "$TRANSITION_ID" == "null" ]]; then
    echo "Warning: Could not find transition '$TARGET_STATUS' for issue ID $issue_id. It might already be in the target status or the transition is not available. Skipping."
    continue
  fi

  echo "Found transition ID '$TRANSITION_ID' for issue $issue_id. Attempting to transition to '$TARGET_STATUS'."

  TRANSITION_URL="${JIRA_BASE_URL}/rest/api/3/issue/${issue_id}/transitions"

  # Perform the transition
  curl -s -u "${JIRA_USER_EMAIL}:${JIRA_API_TOKEN}" \
    -X POST \
    -H "Content-Type: application/json" \
    --data "{\"transition\": {\"id\": \"$TRANSITION_ID\"}}" \
    "$TRANSITION_URL"

  echo "Transition request sent for issue $issue_id."
done

echo "JIRA transition process completed."
