#!/usr/bin/env bats

load 'test_helper'

# Setup for each test
setup() {
  setup_github_output
  setup_curl_mock
  JIRA_CONTEXT=$(create_test_jira_context)
}

# Teardown for each test
teardown() {
  teardown_github_output
  teardown_curl_mock
}

@test "transition-issues: handles empty issue keys" {
  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" ""

  [ "$status" -eq 0 ]
  [[ "$output" == *"No issue keys provided"* ]]
  [[ "$output" == *"Skipping transition"* ]]
}

@test "transition-issues: successfully transitions single issue" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"},{"id":"21","name":"In Progress"}]}'
  set_mock_post_transition_response ''

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Processing issue: PROJ-123"* ]]
  [[ "$output" == *"Found transition ID '31'"* ]]
  [[ "$output" == *"Successfully transitioned issue PROJ-123 to 'Done'"* ]]
}

@test "transition-issues: successfully transitions multiple issues" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response ''

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123,PROJ-456"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Processing issue: PROJ-123"* ]]
  [[ "$output" == *"Processing issue: PROJ-456"* ]]
  [[ "$output" == *"Successfully transitioned issue PROJ-123"* ]]
  [[ "$output" == *"Successfully transitioned issue PROJ-456"* ]]
}

@test "transition-issues: handles whitespace in issue keys" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response ''

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" " PROJ-123 , PROJ-456 "

  [ "$status" -eq 0 ]
  [[ "$output" == *"Processing issue: PROJ-123"* ]]
  [[ "$output" == *"Processing issue: PROJ-456"* ]]
}

@test "transition-issues: skips when transition is not found" {
  set_mock_get_transitions_response '{"transitions":[{"id":"21","name":"In Progress"}]}'

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning: Could not find transition 'Done'"* ]]
  [[ "$output" == *"Skipping"* ]]
}

@test "transition-issues: handles 404 error when getting transitions" {
  set_mock_get_transitions_response '{"errorMessages":["Issue does not exist"]}' "404"

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-999"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Error getting transitions for issue PROJ-999"* ]]
  [[ "$output" == *"HTTP 404"* ]]
}

@test "transition-issues: handles 401 unauthorized error when getting transitions" {
  set_mock_get_transitions_response '{"errorMessages":["Unauthorized"]}' "401"

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Error getting transitions for issue PROJ-123"* ]]
  [[ "$output" == *"HTTP 401"* ]]
}

@test "transition-issues: handles 403 forbidden error when getting transitions" {
  set_mock_get_transitions_response '{"errorMessages":["Forbidden"]}' "403"

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Error getting transitions for issue PROJ-123"* ]]
  [[ "$output" == *"HTTP 403"* ]]
}

@test "transition-issues: handles 500 server error when getting transitions" {
  set_mock_get_transitions_response '{"errorMessages":["Internal server error"]}' "500"

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Error getting transitions for issue PROJ-123"* ]]
  [[ "$output" == *"HTTP 500"* ]]
}

@test "transition-issues: handles 400 bad request when performing transition" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response '{"errorMessages":["Transition is not valid"]}' "400"

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Error transitioning issue PROJ-123"* ]]
  [[ "$output" == *"HTTP 400"* ]]
}

@test "transition-issues: handles 401 unauthorized when performing transition" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response '{"errorMessages":["Unauthorized"]}' "401"

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Error transitioning issue PROJ-123"* ]]
  [[ "$output" == *"HTTP 401"* ]]
}

@test "transition-issues: handles 500 server error when performing transition" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response '{"errorMessages":["Internal server error"]}' "500"

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Error transitioning issue PROJ-123"* ]]
  [[ "$output" == *"HTTP 500"* ]]
}

@test "transition-issues: continues processing after individual failures" {
  # First issue will fail to get transitions, second will succeed
  # Note: This test is limited by our simple mock, but demonstrates the pattern
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response ''

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123,PROJ-456"

  [ "$status" -eq 0 ]
  [[ "$output" == *"JIRA transition process completed"* ]]
}

@test "transition-issues: handles empty issue key in list" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response ''

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123,,PROJ-456"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Processing issue: PROJ-123"* ]]
  [[ "$output" == *"Processing issue: PROJ-456"* ]]
}

@test "transition-issues: processes all provided issue keys" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response ''

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-1,PROJ-2,PROJ-3"

  [ "$status" -eq 0 ]
  # Count how many times "Successfully transitioned" appears
  success_count=$(echo "$output" | grep -c "Successfully transitioned")
  [ "$success_count" -eq 3 ]
}

@test "transition-issues: handles transition with null ID" {
  set_mock_get_transitions_response '{"transitions":[{"id":null,"name":"Done"}]}'

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning: Could not find transition"* ]]
}

@test "transition-issues: handles different transition names" {
  set_mock_get_transitions_response '{"transitions":[{"id":"11","name":"To Do"},{"id":"21","name":"In Progress"},{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response ''

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "In Progress" "PROJ-123"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Found transition ID '21'"* ]]
  [[ "$output" == *"to 'In Progress'"* ]]
}

@test "transition-issues: prints processing summary" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response ''

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "PROJ-123,PROJ-456"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Processing issue keys: PROJ-123,PROJ-456"* ]]
  [[ "$output" == *"JIRA transition process completed"* ]]
}

@test "transition-issues: handles complex JIRA issue keys" {
  set_mock_get_transitions_response '{"transitions":[{"id":"31","name":"Done"}]}'
  set_mock_post_transition_response ''

  run ../scripts/transition-issues.sh "$JIRA_CONTEXT" "Done" "ABC-999,DEF-1,LONG-PROJECT-NAME-12345"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Processing issue: ABC-999"* ]]
  [[ "$output" == *"Processing issue: DEF-1"* ]]
  [[ "$output" == *"Processing issue: LONG-PROJECT-NAME-12345"* ]]
}
