#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/review-gate.sh"
  BOT='github-actions[bot]'
  MARK='<!-- ai-pr-review sha='
}

bot_comment() {
  printf '{"user":{"login":"%s"},"body":"%s\\n### AI review"}' "$1" "$2"
}

@test "review_meta: reads sha and risk from the newest bot comment" {
  comments="[$(bot_comment "$BOT" '<!-- ai-pr-review sha=aaaaaaa risk=low -->'),$(bot_comment "$BOT" '<!-- ai-pr-review sha=bbbbbbb risk=high -->')]"
  [ "$(review_meta "$comments" "$MARK" "$BOT")" = "bbbbbbb high" ]
}

@test "review_meta: a marker comment from anyone else is ignored" {
  comments="[$(bot_comment mallory '<!-- ai-pr-review sha=bbbbbbb risk=low -->')]"
  [ "$(review_meta "$comments" "$MARK" "$BOT")" = "" ]
}

@test "review_meta: a bot comment without sha or risk does not count" {
  comments="[$(bot_comment "$BOT" '<!-- ai-pr-review -->')]"
  [ "$(review_meta "$comments" "$MARK" "$BOT")" = "" ]
}

@test "review_meta: a failure note from the bot is not a review" {
  comments='[{"user":{"login":"github-actions[bot]"},"body":"AI review did not produce a result"}]'
  [ "$(review_meta "$comments" "$MARK" "$BOT")" = "" ]
}

@test "has_label: detects the human review label" {
  [ "$(has_label '[{"name":"bug"},{"name":"needs-human"}]' needs-human)" = "true" ]
  [ "$(has_label '[{"name":"bug"}]' needs-human)" = "false" ]
}

review() {
  printf '{"user":{"login":"%s"},"author_association":"%s","state":"%s","commit_id":"%s","submitted_at":"%s"}' "$@"
}

@test "head_approvers: approval of the head counts" {
  reviews="[$(review bob MEMBER APPROVED head 2026-10-01T10:00:00Z)]"
  [ "$(head_approvers "$reviews" alice head)" = "bob" ]
}

@test "head_approvers: approval of an older commit does not count" {
  reviews="[$(review bob MEMBER APPROVED old 2026-10-01T10:00:00Z)]"
  [ "$(head_approvers "$reviews" alice head)" = "" ]
}

@test "head_approvers: the author's own approval does not count" {
  reviews="[$(review alice MEMBER APPROVED head 2026-10-01T10:00:00Z)]"
  [ "$(head_approvers "$reviews" alice head)" = "" ]
}

@test "head_approvers: a later change request replaces the approval" {
  reviews="[$(review bob MEMBER APPROVED head 2026-10-01T10:00:00Z),$(review bob MEMBER CHANGES_REQUESTED head 2026-10-01T11:00:00Z)]"
  [ "$(head_approvers "$reviews" alice head)" = "" ]
}

@test "head_approvers: a comment after an approval keeps it" {
  reviews="[$(review bob MEMBER APPROVED head 2026-10-01T10:00:00Z),$(review bob MEMBER COMMENTED head 2026-10-01T11:00:00Z)]"
  [ "$(head_approvers "$reviews" alice head)" = "bob" ]
}

@test "head_approvers: a deleted (ghost) reviewer is ignored" {
  reviews='[{"user":null,"author_association":"MEMBER","state":"APPROVED","commit_id":"head","submitted_at":"2026-10-01T10:00:00Z"}]'
  [ "$(head_approvers "$reviews" alice head)" = "" ]
}

mock_permissions() {
  mkdir -p "$BATS_TEST_TMPDIR/bin"
  cat > "$BATS_TEST_TMPDIR/bin/gh" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
  *collaborators/bob/permission*) echo write ;;
  *collaborators/rita/permission*) echo read ;;
  *) exit 1 ;;
esac
MOCK
  chmod +x "$BATS_TEST_TMPDIR/bin/gh"
  PATH="$BATS_TEST_TMPDIR/bin:$PATH"
  REPOSITORY=acme/app
}

@test "has_head_approval: a writer's approval of the head counts" {
  mock_permissions
  reviews="[$(review bob MEMBER APPROVED head 2026-10-01T10:00:00Z)]"
  [ "$(has_head_approval "$reviews" alice head)" = "true" ]
}

@test "has_head_approval: a member with read access does not count" {
  mock_permissions
  reviews="[$(review rita MEMBER APPROVED head 2026-10-01T10:00:00Z)]"
  [ "$(has_head_approval "$reviews" alice head)" = "false" ]
}

@test "has_head_approval: an unknown user does not count" {
  mock_permissions
  reviews="[$(review eve NONE APPROVED head 2026-10-01T10:00:00Z)]"
  [ "$(has_head_approval "$reviews" alice head)" = "false" ]
}

@test "base_in_scope: only the listed base branches need the review" {
  [ "$(base_in_scope develop '["develop"]')" = "true" ]
  [ "$(base_in_scope main '["develop"]')" = "false" ]
}

@test "decide: other base branches pass" {
  [ "$(decide false "" "" headsha false false needs-human)" = "success|No AI review required for this base branch." ]
}

@test "decide: pending until the bot reviewed this commit" {
  [ "$(decide true "" "" 0123456789 false false needs-human)" = "pending|Waiting for the AI review of 0123456. Comment /review to run it." ]
  [ "$(decide true oldsha low 0123456789 false false needs-human)" = "pending|Waiting for the AI review of 0123456. Comment /review to run it." ]
}

@test "decide: a short reviewed sha matches the head" {
  [ "$(decide true 0123456 low 0123456789 false false needs-human)" = "success|AI review done." ]
}

@test "decide: an approval of the head passes without the bot (outage, bot PRs)" {
  [ "$(decide true "" "" 0123456789 false true needs-human)" = "success|Approved by a reviewer; no AI review of this commit." ]
}

@test "decide: high risk waits for an approval even if the label was removed" {
  [ "$(decide true 0123456 high 0123456789 false false needs-human)" = "pending|Needs a human review: waiting for an approval of this commit." ]
}

@test "decide: the label asks for a human even on low risk" {
  [ "$(decide true 0123456 low 0123456789 true false needs-human)" = "pending|Needs a human review: waiting for an approval of this commit." ]
}

@test "decide: high risk with an approval of the head passes" {
  [ "$(decide true 0123456 high 0123456789 false true needs-human)" = "success|AI review done, human review approved." ]
}
