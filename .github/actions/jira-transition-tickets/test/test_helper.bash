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

# Extract the URL and method from arguments
URL=""
METHOD="GET"
WRITE_OUT=""
for arg in "$@"; do
  if [[ "$arg" == http* ]]; then
    URL="$arg"
  fi
  if [[ "$prev_arg" == "-X" ]]; then
    METHOD="$arg"
  fi
  if [[ "$prev_arg" == "-w" ]]; then
    WRITE_OUT="$arg"
  fi
  prev_arg="$arg"
done

# Determine response and status code based on URL and method
if [[ "$URL" == *"/transitions"* ]] && [[ "$METHOD" == "GET" ]]; then
  # Return transitions list
  if [[ -f "$CURL_MOCK_RESPONSES_DIR/get_transitions_status_code.txt" ]]; then
    STATUS_CODE=$(cat "$CURL_MOCK_RESPONSES_DIR/get_transitions_status_code.txt")
  else
    STATUS_CODE="200"
  fi

  if [[ -f "$CURL_MOCK_RESPONSES_DIR/get_transitions_response.json" ]]; then
    cat "$CURL_MOCK_RESPONSES_DIR/get_transitions_response.json"
  else
    echo '{"transitions":[{"id":"31","name":"Done"},{"id":"21","name":"In Progress"}]}'
  fi
elif [[ "$URL" == *"/transitions"* ]] && [[ "$METHOD" == "POST" ]]; then
  # Return transition result
  if [[ -f "$CURL_MOCK_RESPONSES_DIR/post_transition_status_code.txt" ]]; then
    STATUS_CODE=$(cat "$CURL_MOCK_RESPONSES_DIR/post_transition_status_code.txt")
  else
    STATUS_CODE="204"
  fi

  if [[ -f "$CURL_MOCK_RESPONSES_DIR/post_transition_response.json" ]]; then
    cat "$CURL_MOCK_RESPONSES_DIR/post_transition_response.json"
  else
    echo ''
  fi
else
  STATUS_CODE="404"
  echo '{"errorMessages":["Unknown endpoint"]}'
fi

# Output status code if -w flag was provided
if [[ -n "$WRITE_OUT" ]]; then
  echo -n "$STATUS_CODE"
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
# Usage: set_mock_get_transitions_response '{"transitions":[...]}' [status_code]
set_mock_get_transitions_response() {
  echo "$1" > "$CURL_MOCK_RESPONSES_DIR/get_transitions_response.json"
  if [[ -n "$2" ]]; then
    echo "$2" > "$CURL_MOCK_RESPONSES_DIR/get_transitions_status_code.txt"
  else
    echo "200" > "$CURL_MOCK_RESPONSES_DIR/get_transitions_status_code.txt"
  fi
}

# Set a specific mock response for POST transition
# Usage: set_mock_post_transition_response '' [status_code]
set_mock_post_transition_response() {
  echo "$1" > "$CURL_MOCK_RESPONSES_DIR/post_transition_response.json"
  if [[ -n "$2" ]]; then
    echo "$2" > "$CURL_MOCK_RESPONSES_DIR/post_transition_status_code.txt"
  else
    echo "204" > "$CURL_MOCK_RESPONSES_DIR/post_transition_status_code.txt"
  fi
}

# Create base64 encoded JIRA context for testing
# Usage: create_test_jira_context
create_test_jira_context() {
  local jira_context_json='{"cloud_id":"test-cloud-id-123","user_email":"test@example.com","api_token":"test-token-123"}'
  echo "$jira_context_json" | base64
}
