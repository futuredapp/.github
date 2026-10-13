#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/review-gate.sh"
}

@test "has_marker_comment: finds the AI review comment" {
  comments='[{"body":"LGTM"},{"body":"<!-- ai-pr-review -->\n### AI review"}]'
  [ "$(has_marker_comment "$comments" '<!-- ai-pr-review -->')" = "true" ]
}

@test "has_marker_comment: ignores a comment that only mentions the marker later" {
  comments='[{"body":"see <!-- ai-pr-review --> below"},{"body":null}]'
  [ "$(has_marker_comment "$comments" '<!-- ai-pr-review -->')" = "false" ]
}

@test "has_marker_comment: no comments" {
  [ "$(has_marker_comment '[]' '<!-- ai-pr-review -->')" = "false" ]
}

@test "has_label: detects the human review label" {
  [ "$(has_label '[{"name":"bug"},{"name":"needs-human"}]' needs-human)" = "true" ]
  [ "$(has_label '[{"name":"bug"}]' needs-human)" = "false" ]
}

@test "has_approval: approval from another reviewer counts" {
  reviews='[{"user":{"login":"bob"},"state":"APPROVED","submitted_at":"2026-10-01T10:00:00Z"}]'
  [ "$(has_approval "$reviews" alice)" = "true" ]
}

@test "has_approval: the author's own approval does not count" {
  reviews='[{"user":{"login":"alice"},"state":"APPROVED","submitted_at":"2026-10-01T10:00:00Z"}]'
  [ "$(has_approval "$reviews" alice)" = "false" ]
}

@test "has_approval: a later change request replaces the approval" {
  reviews='[
    {"user":{"login":"bob"},"state":"APPROVED","submitted_at":"2026-10-01T10:00:00Z"},
    {"user":{"login":"bob"},"state":"CHANGES_REQUESTED","submitted_at":"2026-10-01T11:00:00Z"}]'
  [ "$(has_approval "$reviews" alice)" = "false" ]
}

@test "has_approval: a comment after an approval keeps it" {
  reviews='[
    {"user":{"login":"bob"},"state":"APPROVED","submitted_at":"2026-10-01T10:00:00Z"},
    {"user":{"login":"bob"},"state":"COMMENTED","submitted_at":"2026-10-01T11:00:00Z"}]'
  [ "$(has_approval "$reviews" alice)" = "true" ]
}

@test "has_approval: a dismissed approval does not count" {
  reviews='[
    {"user":{"login":"bob"},"state":"APPROVED","submitted_at":"2026-10-01T10:00:00Z"},
    {"user":{"login":"bob"},"state":"DISMISSED","submitted_at":"2026-10-01T12:00:00Z"}]'
  [ "$(has_approval "$reviews" alice)" = "false" ]
}

@test "has_approval: no reviews" {
  [ "$(has_approval '[]' alice)" = "false" ]
}

@test "decide: pending until the AI review ran" {
  [ "$(decide false false false needs-human)" = "pending|Waiting for the AI review. Comment /review on the PR to run it." ]
  [ "$(decide false true true needs-human)" = "pending|Waiting for the AI review. Comment /review on the PR to run it." ]
}

@test "decide: success without the label" {
  [ "$(decide true false false needs-human)" = "success|AI review done." ]
}

@test "decide: labeled PR waits for approval" {
  [ "$(decide true true false needs-human)" = "pending|Labeled needs-human: waiting for an approving review." ]
}

@test "decide: labeled PR with approval passes" {
  [ "$(decide true true true needs-human)" = "success|AI review done, human review approved." ]
}
