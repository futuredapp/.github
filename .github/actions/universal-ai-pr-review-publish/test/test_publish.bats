#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/publish.sh"
  WORK=$(mktemp -d)
  export RUNNER_TEMP="$WORK" REPOSITORY=acme/app PR_NUMBER=7 BOT_LOGIN='github-actions[bot]' MARKER='<!-- ai-pr-review sha='
  export HUMAN_REVIEW_LABEL=needs-human FEATURE_LABEL=feature-complete REVIEWER=lead RUN_URL=https://example.com/run
  export GH_LOG="$WORK/gh.log" GH_COMMENTS='[]' GH_FAIL_LABEL_POST=""
  mkdir -p "$WORK/bin"
  cat > "$WORK/bin/gh" <<'MOCK'
#!/usr/bin/env bash
echo "gh $*" >> "$GH_LOG"
case "$*" in
  *"--slurp"*"/comments"*) echo "[$GH_COMMENTS]" ;;
  "api --method POST repos/acme/app/issues/7/labels"*) [ -n "$GH_FAIL_LABEL_POST" ] && exit 1; echo '{}' ;;
  "api repos/acme/app/pulls/7 --jq .user.login") echo author ;;
  "api repos/acme/app/labels/"*) echo '{}' ;;
  *) echo '{}' ;;
esac
MOCK
  chmod +x "$WORK/bin/gh"
  export PATH="$WORK/bin:$PATH"
  export RESULT_FILE="$WORK/result.json" BODY_FILE="$WORK/comment.md"
}

teardown() {
  rm -rf "$WORK"
}

@test "bot_comment_id: picks the newest bot comment with the marker" {
  comments='[{"id":1,"user":{"login":"github-actions[bot]"},"body":"<!-- ai-pr-review sha=a risk=low -->"},{"id":2,"user":{"login":"github-actions[bot]"},"body":"<!-- ai-pr-review sha=b risk=low -->"}]'
  [ "$(bot_comment_id "$comments" "$MARKER" "$BOT_LOGIN")" = "2" ]
}

@test "bot_comment_id: never picks a comment written by someone else" {
  comments='[{"id":9,"user":{"login":"mallory"},"body":"<!-- ai-pr-review sha=b risk=low -->"}]'
  [ "$(bot_comment_id "$comments" "$MARKER" "$BOT_LOGIN")" = "" ]
}

@test "reviewer_payload: a login requests a user, org/team a team" {
  [ "$(reviewer_payload jdoe)" = '{"reviewers":["jdoe"]}' ]
  [ "$(reviewer_payload acme/ios)" = '{"team_reviewers":["ios"]}' ]
}

@test "main: high risk is labeled before the comment is posted" {
  echo '{"risk":{"level":"high"}}' > "$RESULT_FILE"
  printf '<!-- ai-pr-review sha=abc risk=high -->\nbody\n' > "$BODY_FILE"
  run bash "$BATS_TEST_DIRNAME/../scripts/publish.sh"
  [ "$status" -eq 0 ]
  label_line=$(grep -n "issues/7/labels" "$GH_LOG" | head -1 | cut -d: -f1)
  comment_line=$(grep -n "POST repos/acme/app/issues/7/comments" "$GH_LOG" | head -1 | cut -d: -f1)
  [ -n "$label_line" ] && [ -n "$comment_line" ] && [ "$label_line" -lt "$comment_line" ]
}

@test "main: a failed label leaves no fresh review comment" {
  export GH_FAIL_LABEL_POST=1
  echo '{"risk":{"level":"high"}}' > "$RESULT_FILE"
  printf '<!-- ai-pr-review sha=abc risk=high -->\nbody\n' > "$BODY_FILE"
  run bash "$BATS_TEST_DIRNAME/../scripts/publish.sh"
  [ "$status" -ne 0 ]
  ! grep -q "POST repos/acme/app/issues/7/comments" "$GH_LOG"
}

@test "main: no result posts the failure note and fails" {
  : > "$RESULT_FILE"; : > "$BODY_FILE"
  run bash "$BATS_TEST_DIRNAME/../scripts/publish.sh"
  [ "$status" -eq 1 ]
  grep -q "POST repos/acme/app/issues/7/comments" "$GH_LOG"
}

@test "main: a body without the marker counts as no result" {
  echo '{"risk":{"level":"low"}}' > "$RESULT_FILE"
  printf 'something else\n' > "$BODY_FILE"
  run bash "$BATS_TEST_DIRNAME/../scripts/publish.sh"
  [ "$status" -eq 1 ]
}
