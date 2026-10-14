#!/bin/bash
# Publishes an AI review result: one sticky PR comment, the human review label for high risk,
# and a review request for the project reviewer. Posts a failure note when the review produced no result.
set -euo pipefail

# marker_comment_id <comments_json> <marker>: id of the newest comment whose body starts with the marker, or empty.
marker_comment_id() {
  jq -r --arg marker "$2" '[.[] | select((.body // "") | startswith($marker))] | last | .id // empty' <<< "$1"
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

# ensure_label <name> <color> <description>: creates the label when the repository does not have it yet.
ensure_label() {
  if ! gh api "repos/$REPOSITORY/labels/$(jq -rn --arg n "$1" '$n | @uri')" > /dev/null 2>&1; then
    gh label create "$1" --repo "$REPOSITORY" --color "$2" --description "$3" > /dev/null
  fi
}

upsert_comment() {
  local comments comment_id
  comments=$(gh api --paginate --slurp "repos/$REPOSITORY/issues/$PR_NUMBER/comments" | jq -c 'add // []')
  comment_id=$(marker_comment_id "$comments" "$MARKER")
  if [ -n "$comment_id" ]; then
    gh api --method PATCH "repos/$REPOSITORY/issues/comments/$comment_id" -F body=@"$BODY_FILE" > /dev/null
  else
    gh api --method POST "repos/$REPOSITORY/issues/$PR_NUMBER/comments" -F body=@"$BODY_FILE" > /dev/null
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
  ensure_label "$HUMAN_REVIEW_LABEL" "B60205" "Needs a human code review before merge"
  ensure_label "$FEATURE_LABEL" "0E8A16" "Completes a functional whole worth trying in the app"

  if [ ! -s "$BODY_FILE" ] || [ ! -s "$RESULT_FILE" ]; then
    gh api --method POST "repos/$REPOSITORY/issues/$PR_NUMBER/comments" \
      -f body="AI review did not produce a result ([run log]($RUN_URL)). Comment \`/review\` to try again." > /dev/null
    echo "::error::AI review produced no result."
    exit 1
  fi

  upsert_comment
  if [ "$(jq -r '.risk.level' "$RESULT_FILE")" = "high" ]; then
    flag_for_human_review
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
