#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== JIRA Transition Integration Test ===${NC}\n"

# ============================================
# Script Arguments
# ============================================

TRANSITION_NAME="$1"
MERGED_BRANCHES="$2"

# ============================================
# Environment Variables (JIRA Credentials)
# ============================================

# Option 1: Provide base64-encoded JIRA context directly
JIRA_CONTEXT="${JIRA_CONTEXT:-}"

# Option 2: Provide individual credentials (will be encoded automatically)
JIRA_CLOUD_ID="${JIRA_CLOUD_ID:-}"
JIRA_USER_EMAIL="${JIRA_USER_EMAIL:-}"
JIRA_API_TOKEN="${JIRA_API_TOKEN:-}"

# ============================================
# Validation
# ============================================

# Check required inputs
MISSING_PARAMS=()

if [[ -z "$TRANSITION_NAME" ]]; then
  MISSING_PARAMS+=("TRANSITION_NAME")
fi

if [[ -z "$MERGED_BRANCHES" ]]; then
  MISSING_PARAMS+=("MERGED_BRANCHES")
fi

if [[ -z "$JIRA_CONTEXT" ]]; then
  # No pre-encoded context, check for individual credentials
  if [[ -z "$JIRA_CLOUD_ID" ]] || [[ -z "$JIRA_USER_EMAIL" ]] || [[ -z "$JIRA_API_TOKEN" ]]; then
    MISSING_PARAMS+=("JIRA credentials")
  fi
  USE_PRE_ENCODED=false
else
  USE_PRE_ENCODED=true
fi

if [[ ${#MISSING_PARAMS[@]} -gt 0 ]]; then
  echo -e "${RED}Error: Missing required parameters: ${MISSING_PARAMS[*]}${NC}"
  echo ""
  echo "Usage:"
  echo "  $0 <transition_name> <merged_branches>"
  echo ""
  echo "Example:"
  echo "  $0 'Done' 'feature/ABC-123,feature/XYZ-456'"
  echo ""
  echo "JIRA credentials must be set as environment variables (choose one option):"
  echo ""
  echo "Option 1 - Provide base64-encoded JIRA context:"
  echo "  export JIRA_CONTEXT='<base64-encoded-json>'"
  echo ""
  echo "Option 2 - Provide individual credentials:"
  echo "  export JIRA_CLOUD_ID='your-cloud-id'"
  echo "  export JIRA_USER_EMAIL='your-email@example.com'"
  echo "  export JIRA_API_TOKEN='your-api-token'"
  echo ""
  exit 1
fi

echo -e "${YELLOW}Configuration:${NC}"
if [[ "$USE_PRE_ENCODED" == "true" ]]; then
  echo "  JIRA Context:    <pre-encoded base64>"
else
  echo "  Cloud ID:        $JIRA_CLOUD_ID"
  echo "  User Email:      $JIRA_USER_EMAIL"
fi
echo "  Transition:      $TRANSITION_NAME"
echo "  Merged Branches: $MERGED_BRANCHES"
echo ""

# ============================================
# Step 1: Run extract-issue-keys.sh
# ============================================

echo -e "${BLUE}Step 1: Extracting issue keys from branches${NC}"

# Create a temporary file to simulate GITHUB_OUTPUT
TEMP_OUTPUT=$(mktemp)
export GITHUB_OUTPUT="$TEMP_OUTPUT"

# Run the extraction script
../scripts/extract-issue-keys.sh "$MERGED_BRANCHES"

# Read the output
if [[ ! -f "$TEMP_OUTPUT" ]]; then
  echo -e "${RED}Error: extract-issue-keys.sh did not create output file${NC}"
  exit 1
fi

ISSUE_KEYS=$(grep "issue_keys=" "$TEMP_OUTPUT" | cut -d'=' -f2-)

echo -e "${GREEN}✓ Extracted issue keys: ${ISSUE_KEYS}${NC}"
echo ""

if [[ -z "$ISSUE_KEYS" ]]; then
  echo -e "${YELLOW}Warning: No issue keys found in branches. Nothing to transition.${NC}"
  rm -f "$TEMP_OUTPUT"
  exit 0
fi

# ============================================
# Step 2: Prepare JIRA context
# ============================================

echo -e "${BLUE}Step 2: Preparing JIRA context${NC}"

if [[ "$USE_PRE_ENCODED" == "true" ]]; then
  # Use the pre-encoded context
  JIRA_CONTEXT_BASE64="$JIRA_CONTEXT"
  echo -e "${GREEN}✓ Using pre-encoded JIRA context${NC}"
else
  # Create the JIRA context JSON from individual credentials
  JIRA_CONTEXT_JSON=$(jq -n \
    --arg cloud_id "$JIRA_CLOUD_ID" \
    --arg user_email "$JIRA_USER_EMAIL" \
    --arg api_token "$JIRA_API_TOKEN" \
    '{cloud_id: $cloud_id, user_email: $user_email, api_token: $api_token}')

  # Base64 encode it
  JIRA_CONTEXT_BASE64=$(echo "$JIRA_CONTEXT_JSON" | base64)
  echo -e "${GREEN}✓ JIRA context created and encoded${NC}"
fi
echo ""

# ============================================
# Step 3: Run transition-issues.sh
# ============================================

echo -e "${BLUE}Step 3: Transitioning JIRA issues${NC}"
echo ""

# Run the transition script
../scripts/transition-issues.sh \
  "$JIRA_CONTEXT_BASE64" \
  "$TRANSITION_NAME" \
  "$ISSUE_KEYS"

echo ""
echo -e "${GREEN}=== Integration test completed ===${NC}"

# Cleanup
rm -f "$TEMP_OUTPUT"
