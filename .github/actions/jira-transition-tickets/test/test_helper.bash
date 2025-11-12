#!/usr/bin/env bash

# Test helper functions for BATS tests

# Setup GITHUB_OUTPUT for tests that need it
setup_github_output() {
  export GITHUB_OUTPUT=$(mktemp)
}

# Clean up GITHUB_OUTPUT
teardown_github_output() {
  rm -f "$GITHUB_OUTPUT"
}

# Mock curl for transition-issues.sh tests
# Usage: setup_curl_mock
# Sets up curl mocking by creating a mock curl function
setup_curl_mock() {
  export CURL_MOCK_RESPONSES_DIR=$(mktemp -d)
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"

  # Create mock curl script
  mkdir -p "$BATS_TEST_DIRNAME/mocks"
  cat > "$BATS_TEST_DIRNAME/mocks/curl" << 'EOF'
#!/usr/bin/env bash
# Mock curl for testing

# Extract the URL from arguments
URL=""
METHOD="GET"
for arg in "$@"; do
  if [[ "$arg" == http* ]]; then
    URL="$arg"
  fi
  if [[ "$prev_arg" == "-X" ]]; then
    METHOD="$arg"
  fi
  prev_arg="$arg"
done

# Determine response based on URL and method
if [[ "$URL" == *"/transitions"* ]] && [[ "$METHOD" == "GET" ]]; then
  # Return transitions list
  if [[ -f "$CURL_MOCK_RESPONSES_DIR/get_transitions_response.json" ]]; then
    cat "$CURL_MOCK_RESPONSES_DIR/get_transitions_response.json"
  else
    echo '{"transitions":[{"id":"31","name":"Done"},{"id":"21","name":"In Progress"}]}'
  fi
elif [[ "$URL" == *"/transitions"* ]] && [[ "$METHOD" == "POST" ]]; then
  # Return transition result
  if [[ -f "$CURL_MOCK_RESPONSES_DIR/post_transition_response.json" ]]; then
    cat "$CURL_MOCK_RESPONSES_DIR/post_transition_response.json"
  else
    echo ''
  fi
else
  echo '{"errorMessages":["Unknown endpoint"]}'
fi
EOF
  chmod +x "$BATS_TEST_DIRNAME/mocks/curl"
}

# Clean up curl mock
teardown_curl_mock() {
  rm -rf "$CURL_MOCK_RESPONSES_DIR"
  rm -f "$BATS_TEST_DIRNAME/mocks/curl"
  rmdir "$BATS_TEST_DIRNAME/mocks" 2>/dev/null || true
}

# Set a specific mock response for GET transitions
# Usage: set_mock_transitions_response '{"transitions":[...]}'
set_mock_get_transitions_response() {
  echo "$1" > "$CURL_MOCK_RESPONSES_DIR/get_transitions_response.json"
}

# Set a specific mock response for POST transition
# Usage: set_mock_transition_result '{"errorMessages":[...]}'
set_mock_post_transition_response() {
  echo "$1" > "$CURL_MOCK_RESPONSES_DIR/post_transition_response.json"
}

# Create base64 encoded JIRA context for testing
# Usage: create_test_jira_context
create_test_jira_context() {
  local jira_context_json='{"base_url":"https://test.atlassian.net","user_email":"test@example.com","api_token":"test-token-123"}'
  echo "$jira_context_json" | base64
}
