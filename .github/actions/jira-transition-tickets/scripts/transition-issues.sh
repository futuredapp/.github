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

echo "Processing issue keys: $ISSUE_KEYS"

# Split comma-separated issue keys
IFS=',' read -ra KEYS <<< "$ISSUE_KEYS"

# Loop through each issue key and transition it
for issue_key in "${KEYS[@]}"; do
  # Trim whitespace
  issue_key=$(echo "$issue_key" | xargs)

  if [[ -z "$issue_key" ]]; then
    continue
  fi

  echo "Processing issue: $issue_key"

  # Get available transitions for this issue
  TRANSITIONS_URL="${JIRA_BASE_URL}/rest/api/3/issue/${issue_key}/transitions"

  TRANSITIONS_FULL_RESPONSE=$(curl -s -u "${JIRA_USER_EMAIL}:${JIRA_API_TOKEN}" \
    -X GET -H "Content-Type: application/json" \
    -w '\n%{http_code}' \
    "$TRANSITIONS_URL")

  # Extract HTTP status code (last line) and response body (everything else)
  TRANSITIONS_HTTP_CODE=$(echo "$TRANSITIONS_FULL_RESPONSE" | tail -n1)
  TRANSITIONS_RESPONSE=$(echo "$TRANSITIONS_FULL_RESPONSE" | sed '$d')

  # Check if the HTTP status code indicates success (2xx)
  if [[ ! "$TRANSITIONS_HTTP_CODE" =~ ^2[0-9]{2}$ ]]; then
    echo "Error getting transitions for issue $issue_key: HTTP $TRANSITIONS_HTTP_CODE"
    if [[ -n "$TRANSITIONS_RESPONSE" ]]; then
      echo "$TRANSITIONS_RESPONSE" | jq . 2>/dev/null || echo "$TRANSITIONS_RESPONSE"
    fi
    continue
  fi

  # Find the transition ID by matching the transition name
  TRANSITION_ID=$(echo "$TRANSITIONS_RESPONSE" | \
    jq -r --arg name "$TRANSITION_NAME" \
    '.transitions[] | select(.name == $name) | .id')

  if [[ -z "$TRANSITION_ID" || "$TRANSITION_ID" == "null" ]]; then
    echo "Warning: Could not find transition '$TRANSITION_NAME' for issue $issue_key. It might already be in the target status or the transition is not available. Skipping."
    continue
  fi

  echo "Found transition ID '$TRANSITION_ID' for issue $issue_key. Attempting to transition to '$TRANSITION_NAME'."

  # Perform the transition
  TRANSITION_URL="${JIRA_BASE_URL}/rest/api/3/issue/${issue_key}/transitions"

  TRANSITION_FULL_RESULT=$(curl -s -u "${JIRA_USER_EMAIL}:${JIRA_API_TOKEN}" \
    -X POST \
    -H "Content-Type: application/json" \
    -w '\n%{http_code}' \
    --data "{\"transition\": {\"id\": \"$TRANSITION_ID\"}}" \
    "$TRANSITION_URL")

  # Extract HTTP status code (last line) and response body (everything else)
  TRANSITION_HTTP_CODE=$(echo "$TRANSITION_FULL_RESULT" | tail -n1)
  TRANSITION_RESULT=$(echo "$TRANSITION_FULL_RESULT" | sed '$d')

  # Check if the HTTP status code indicates success (2xx)
  if [[ ! "$TRANSITION_HTTP_CODE" =~ ^2[0-9]{2}$ ]]; then
    echo "Error transitioning issue $issue_key: HTTP $TRANSITION_HTTP_CODE"
    if [[ -n "$TRANSITION_RESULT" ]]; then
      echo "$TRANSITION_RESULT" | jq . 2>/dev/null || echo "$TRANSITION_RESULT"
    fi
  else
    echo "Successfully transitioned issue $issue_key to '$TRANSITION_NAME'."
  fi
done

echo "JIRA transition process completed."
