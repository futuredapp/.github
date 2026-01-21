#!/usr/bin/env bats

load 'test_helper'

# Setup for each test
setup() {
  setup_github_output
}

# Teardown for each test
teardown() {
  teardown_github_output
}

@test "extract-issue-keys: handles empty input" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" ""

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "" ]
}

@test "extract-issue-keys: extracts single JIRA key from branch" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123-add-feature"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123" ]
}

@test "extract-issue-keys: extracts single JIRA key from branch with just issue key" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123" ]
}

@test "extract-issue-keys: extracts multiple JIRA keys from single branch" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123-PROJ-456-combine"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123,PROJ-456" ]
}

@test "extract-issue-keys: extracts keys from multiple branches" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123-feature,bugfix/PROJ-456-fix"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123,PROJ-456" ]
}

@test "extract-issue-keys: removes duplicate JIRA keys" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123-feature,bugfix/PROJ-123-fix"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123" ]
}

@test "extract-issue-keys: handles branch without JIRA key" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/some-feature"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "" ]
}

@test "extract-issue-keys: handles mixed branches (with and without keys)" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123-feature,hotfix/some-fix,bugfix/PROJ-456-bug"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123,PROJ-456" ]
}

@test "extract-issue-keys: handles whitespace in branch names" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" " feature/PROJ-123-feature , bugfix/PROJ-456-fix "

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123,PROJ-456" ]
}

@test "extract-issue-keys: extracts keys with different project prefixes" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/ABC-123-DEF-456-GHI-789"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "ABC-123,DEF-456,GHI-789" ]
}

@test "extract-issue-keys: extracts JIRA key at start of branch name" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "PROJ-123-feature-branch"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123" ]
}

@test "extract-issue-keys: extracts JIRA key in middle of branch name" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature-PROJ-123-branch"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123" ]
}

@test "extract-issue-keys: extracts JIRA key at end of branch name" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature-branch-PROJ-123"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123" ]
}

@test "extract-issue-keys: ignores lowercase project codes" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/proj-123-test"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "" ]
}

@test "extract-issue-keys: handles special characters in branch names" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123_with_underscores,bugfix/PROJ-456-with-dashes"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123,PROJ-456" ]
}

@test "extract-issue-keys: handles multiple branches with sorting" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "PROJ-3,PROJ-1,PROJ-2"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-1,PROJ-2,PROJ-3" ]
}

@test "extract-issue-keys: handles duplicate keys in same branch" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123-and-PROJ-123-again"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123" ]
}

@test "extract-issue-keys: handles complex multi-branch scenario with duplicates" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123-ABC-456,bugfix/PROJ-123-DEF-789,hotfix/ABC-456"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "ABC-456,DEF-789,PROJ-123" ]
}

@test "extract-issue-keys: handles JIRA keys with large numbers" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-999999-test"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-999999" ]
}

@test "extract-issue-keys: handles JIRA keys with short project codes" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/AB-123-test"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "AB-123" ]
}

@test "extract-issue-keys: handles multiple commas in input" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/PROJ-123,,,bugfix/PROJ-456"

  [ "$status" -eq 0 ]
  result="$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)"
  # Should contain both keys
  echo "$result" | grep -q "PROJ-123"
  echo "$result" | grep -q "PROJ-456"
}

@test "extract-issue-keys: handles branch with slash in name" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/team/PROJ-123-description"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-123" ]
}

@test "extract-issue-keys: handles number in project identifier" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/team/PROJ25-123-description"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ25-123" ]
}


@test "extract-issue-keys: handles multiple issue keys with number in project identifier" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "feature/team/PROJ25-123-description,feature/PROJ25-456-description"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ25-123,PROJ25-456" ]
}

@test "extract-issue-keys: handles single quotes" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "Merge remote-tracking branch 'origin/develop, feature/PROJ-1011-eaa-login, futuredapp/feature/PROJ-1009-eaa-intro"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-1009,PROJ-1011" ]
}

@test "extract-issue-keys: handles double quotes" {
  run "$BATS_TEST_DIRNAME/../scripts/extract-issue-keys.sh" "Merge remote-tracking branch 'origin/develop', feature/PROJ-1011-eaa-login, futuredapp/feature/PROJ-1009-eaa-intro"

  [ "$status" -eq 0 ]
  [ "$(grep '^issue_keys=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "PROJ-1009,PROJ-1011" ]
}

