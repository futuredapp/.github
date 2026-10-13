#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/publish.sh"
}

@test "marker_comment_id: picks the newest marker comment" {
  comments='[{"id":1,"body":"<!-- ai-pr-review -->\nold"},{"id":2,"body":"thanks"},{"id":3,"body":"<!-- ai-pr-review -->\nnew"}]'
  [ "$(marker_comment_id "$comments" '<!-- ai-pr-review -->')" = "3" ]
}

@test "marker_comment_id: empty when no marker comment exists" {
  comments='[{"id":1,"body":"AI review did not produce a result"},{"id":2,"body":null}]'
  [ "$(marker_comment_id "$comments" '<!-- ai-pr-review -->')" = "" ]
}

@test "reviewer_payload: a login requests a user" {
  [ "$(reviewer_payload jdoe)" = '{"reviewers":["jdoe"]}' ]
}

@test "reviewer_payload: org/team requests a team by slug" {
  [ "$(reviewer_payload acme/ios-reviewers)" = '{"team_reviewers":["ios-reviewers"]}' ]
}
