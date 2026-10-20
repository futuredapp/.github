#!/bin/bash
# Publishes an AI review result: the human review label and a review request for high risk first,
# then one sticky PR comment. Without a result it keeps one sticky failure note instead.
set -euo pipefail

FAILURE_MARKER="<!-- ai-pr-review-failed -->"

# bot_comment_id <comments_json> <marker> <bot_login>: id of the newest bot comment starting with the marker, or empty.
bot_comment_id() {
  jq -r --arg marker "$2" --arg bot "$3" '
    [ .[] | select(.user.login == $bot) | select((.body // "") | startswith($marker)) ] | last | .id // empty' <<< "$1"
}

# reviewer_payload <reviewer>: request body for the requested_reviewers API; "org/team" requests a team.
reviewer_payload() {
  local reviewer="$1"
  if [[ "$reviewer" == */* ]]; then
    jq -cn --arg team "${reviewer#*/}" '{team_reviewers: [$team]}'
  else
    jq -cn --arg user "$reviewer" '{reviewers: [$user]}'
  fi
}

label_exists() {
  gh api "repos/$REPOSITORY/labels/$(jq -rn --arg n "$1" '$n | @uri')" > /dev/null 2>&1
}

# ensure_label <name> <color> <description>: creates the label when missing; a concurrent creation is fine.
ensure_label() {
  label_exists "$1" && return 0
  gh label create "$1" --repo "$REPOSITORY" --color "$2" --description "$3" > /dev/null 2>&1 || label_exists "$1"
}

pr_comments() {
  gh api --paginate --slurp "repos/$REPOSITORY/issues/$PR_NUMBER/comments" | jq -c 'add // []'
}

# upsert_comment <marker> <body_file>: edits the bot's comment with this marker, or posts a new one.
upsert_comment() {
  local comment_id
  comment_id=$(bot_comment_id "$(pr_comments)" "$1" "$BOT_LOGIN")
  if [ -n "$comment_id" ]; then
    gh api --method PATCH "repos/$REPOSITORY/issues/comments/$comment_id" -F body=@"$2" > /dev/null
  else
    gh api --method POST "repos/$REPOSITORY/issues/$PR_NUMBER/comments" -F body=@"$2" > /dev/null
  fi
}

delete_failure_note() {
  local comment_id
  comment_id=$(bot_comment_id "$(pr_comments)" "$FAILURE_MARKER" "$BOT_LOGIN")
  if [ -n "$comment_id" ]; then
    gh api --method DELETE "repos/$REPOSITORY/issues/comments/$comment_id" > /dev/null || true
  fi
}

flag_for_human_review() {
  local author
  gh api --method POST "repos/$REPOSITORY/issues/$PR_NUMBER/labels" -f "labels[]=$HUMAN_REVIEW_LABEL" > /dev/null
  author=$(gh api "repos/$REPOSITORY/pulls/$PR_NUMBER" --jq '.user.login')
  if [ -n "$REVIEWER" ] && [ "$REVIEWER" != "$author" ]; then
    reviewer_payload "$REVIEWER" | gh api --method POST "repos/$REPOSITORY/pulls/$PR_NUMBER/requested_reviewers" --input - > /dev/null \
      || echo "::warning::Could not request a review from $REVIEWER."
  fi
}

main() {
  local head_sha
  head_sha=$(gh api "repos/$REPOSITORY/pulls/$PR_NUMBER" --jq '.head.sha')
  if [ -n "${REVIEWED_SHA:-}" ] && [ "$head_sha" != "$REVIEWED_SHA" ]; then
    echo "PR head moved from $REVIEWED_SHA to $head_sha; the newer run publishes its own result."
    exit 0
  fi

  ensure_label "$HUMAN_REVIEW_LABEL" "B60205" "Needs a human code review before merge"
  ensure_label "$FEATURE_LABEL" "0E8A16" "Completes a functional whole worth trying in the app"

  local first_line=""
  [ -s "$BODY_FILE" ] && { IFS= read -r first_line < "$BODY_FILE" || true; }
  if [ ! -s "$RESULT_FILE" ] || [[ "$first_line" != "$MARKER"* ]]; then
    printf '%s\nAI review did not produce a result for this commit ([run log](%s)). Comment `/review` to try again, or get an approval.\n' \
      "$FAILURE_MARKER" "$RUN_URL" > "$RUNNER_TEMP/ai-review-failure.md"
    upsert_comment "$FAILURE_MARKER" "$RUNNER_TEMP/ai-review-failure.md"
    echo "::error::AI review produced no result."
    exit 1
  fi

  # Label before comment: if labeling fails, no fresh review comment can turn the gate green.
  if [ "$(jq -r '.risk.level' "$RESULT_FILE")" = "high" ]; then
    flag_for_human_review
  fi
  upsert_comment "$MARKER" "$BODY_FILE"
  delete_failure_note
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
