#!/bin/bash
# Posts a Slack message listing the PRs in a build's commit range that carry the feature label,
# so the project's reviewer knows which finished features to try in the app.
set -euo pipefail

# extract_section <markdown> <heading>: text under "## <heading>" up to the next heading, outside code fences,
# without template placeholder comments and blank edge lines. Reads the whole input (no early exit, no SIGPIPE).
extract_section() {
  tr -d '\r' <<< "$1" | HEADING="## $2" awk '
    { line = $0; sub(/[ \t]+$/, "", line) }
    /^```/ { fence = !fence }
    !fence && /^##? / { if (found) done = 1; else if (line == ENVIRON["HEADING"]) { found = 1; next } }
    found && !done && line !~ /^[ \t]*<!--.*-->$/ { print }
  ' | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}'
}

# prs_in_range <prs_json> <range_shas_json>: PRs whose merge commit is one of the range commits, with their "What to try" text.
prs_in_range() {
  jq -c --argjson shas "$2" '[ .[] | select(.mergeCommit.oid as $oid | $shas | index($oid)) ]' <<< "$1"
}

# slack_escape <text>: escapes the characters Slack mrkdwn treats as control characters.
slack_escape() {
  sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' <<< "$1"
}

# build_payload <prs_json> <build_name> <reviewer_mention> <heading>: Slack webhook payload.
build_payload() {
  local prs="$1" build_name="$2" reviewer="$3" heading="$4"
  local count text title try line
  count=$(jq 'length' <<< "$prs")

  text="*$(slack_escape "$build_name")* is out with $count finished feature(s) to try in the app"
  if [ -n "$reviewer" ]; then
    text+=", $reviewer"
  fi
  text+=":"

  while IFS= read -r pr; do
    title=$(slack_escape "$(jq -r '.title' <<< "$pr")")
    line="• <$(jq -r '.url' <<< "$pr")|#$(jq -r '.number' <<< "$pr") $title>"
    try=$(extract_section "$(jq -r '.body // ""' <<< "$pr")" "$heading")
    try="${try:0:600}"
    if [ -n "$try" ]; then
      line+=$'\n'"$(slack_escape "$try" | sed 's/^/>/')"
    fi
    text+=$'\n'"$line"
  done < <(jq -c '.[]' <<< "$prs")

  jq -cn --arg text "$text" '{text: $text}'
}

main() {
  local range_shas since prs matched payload

  range_shas=$(gh api --paginate "repos/$REPOSITORY/compare/$FROM_COMMIT...$TO_COMMIT?per_page=100" --jq '.commits[].sha' \
    | jq -Rsc 'split("\n") | map(select(length > 0))')
  since=$(gh api "repos/$REPOSITORY/commits/$FROM_COMMIT" --jq '.commit.committer.date')
  prs=$(gh pr list --repo "$REPOSITORY" --state merged --label "$LABEL" --search "merged:>=$since" --limit 200 \
    --json number,title,url,body,mergeCommit)
  matched=$(prs_in_range "$prs" "$range_shas")

  if [ "$(jq 'length' <<< "$matched")" -eq 0 ]; then
    echo "No PRs labeled $LABEL in this build."
    exit 0
  fi

  payload=$(build_payload "$matched" "$BUILD_NAME" "$REVIEWER_MENTION" "$SECTION_HEADING")
  if [ -z "$SLACK_WEBHOOK_URL" ]; then
    echo "No Slack webhook provided, printing the message instead."
    jq -r '.text' <<< "$payload"
    exit 0
  fi
  curl -sS -f -X POST -H 'Content-type: application/json' --data-binary @- "$SLACK_WEBHOOK_URL" <<< "$payload" > /dev/null
  echo "Notified about $(jq 'length' <<< "$matched") PR(s)."
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
