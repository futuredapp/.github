#!/bin/bash
# Sets the review gate commit status on the PR head. Green when the AI review bot reviewed exactly this commit
# and, for high-risk results or PRs labeled for human review, a writer other than the author approved this commit.
# An approval of the head commit alone also turns it green, so an AI outage or a bot-authored PR never blocks forever.
set -euo pipefail

# review_meta <comments_json> <marker> <bot_login>: "sha risk" from the newest marker comment written by the bot, or empty.
# The marker's first line looks like: <!-- ai-pr-review sha=<commit> risk=<low|high> -->
review_meta() {
  jq -r --arg marker "$2" --arg bot "$3" '
    [ .[] | select(.user.login == $bot) | select((.body // "") | startswith($marker)) ]
    | last | (.body // "") | split("\n")[0]
    | (capture("sha=(?<sha>[0-9a-f]{7,40})") // {}) as $s
    | (capture("risk=(?<risk>low|high)") // {}) as $r
    | if $s.sha and $r.risk then "\($s.sha) \($r.risk)" else empty end' <<< "$1"
}

# has_label <labels_json> <label>: "true" when the PR carries the label.
has_label() {
  jq -r --arg label "$2" 'any(.[]; .name == $label)' <<< "$1"
}

# head_approvers <reviews_json> <author> <head_sha>: logins, other than the author, whose latest decisive review
# is an APPROVED review of the head commit.
head_approvers() {
  jq -r --arg author "$2" --arg head "$3" '
    [ .[]
      | select(.user != null and .user.login != $author)
      | select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "DISMISSED") ]
    | group_by(.user.login)
    | map(sort_by(.submitted_at) | last)
    | .[] | select(.state == "APPROVED" and .commit_id == $head) | .user.login' <<< "$1"
}

# has_write_access <login>: author_association does not imply write access, the collaborator permission does.
has_write_access() {
  local permission
  permission=$(gh api "repos/$REPOSITORY/collaborators/$1/permission" --jq '.permission' 2> /dev/null || echo none)
  [[ "$permission" == "admin" || "$permission" == "maintain" || "$permission" == "write" ]]
}

# has_head_approval <reviews_json> <author> <head_sha>: "true" when a writer other than the author approved the head.
has_head_approval() {
  local login
  while IFS= read -r login; do
    if [ -n "$login" ] && has_write_access "$login"; then
      echo "true"
      return
    fi
  done < <(head_approvers "$1" "$2" "$3")
  echo "false"
}

# base_in_scope <base_ref> <branches_json>: "true" when PRs into this base branch need the AI review.
base_in_scope() {
  jq -rn --arg base "$1" --argjson branches "$2" '$branches | index($base) != null'
}

# decide <in_scope> <reviewed_sha> <risk> <head_sha> <labeled> <approved> <label>: prints "state|description".
decide() {
  local in_scope="$1" reviewed_sha="$2" risk="$3" head_sha="$4" labeled="$5" approved="$6" label="$7"

  if [ "$in_scope" != "true" ]; then
    echo "success|No AI review required for this base branch."
  elif [ -z "$reviewed_sha" ] || [[ "$head_sha" != "$reviewed_sha"* ]]; then
    if [ "$approved" = "true" ]; then
      echo "success|Approved by a reviewer; no AI review of this commit."
    else
      echo "pending|Waiting for the AI review of ${head_sha:0:7}. Comment /review to run it."
    fi
  elif [ "$risk" = "high" ] || [ "$labeled" = "true" ]; then
    if [ "$approved" = "true" ]; then
      echo "success|AI review done, human review approved."
    else
      echo "pending|Needs a human review: waiting for an approval of this commit."
    fi
  else
    echo "success|AI review done."
  fi
}

main() {
  local pr_json head_sha author base labels comments reviews meta reviewed_sha="" risk="" in_scope labeled approved decision

  pr_json=$(gh api "repos/$REPOSITORY/pulls/$PR_NUMBER")
  head_sha=$(jq -r '.head.sha' <<< "$pr_json")
  author=$(jq -r '.user.login' <<< "$pr_json")
  base=$(jq -r '.base.ref' <<< "$pr_json")
  labels=$(jq -c '.labels' <<< "$pr_json")
  comments=$(gh api --paginate --slurp "repos/$REPOSITORY/issues/$PR_NUMBER/comments" | jq -c 'add // []')
  reviews=$(gh api --paginate --slurp "repos/$REPOSITORY/pulls/$PR_NUMBER/reviews" | jq -c 'add // []')

  meta=$(review_meta "$comments" "$MARKER" "$BOT_LOGIN")
  if [ -n "$meta" ]; then
    reviewed_sha="${meta%% *}"
    risk="${meta#* }"
  fi
  in_scope=$(base_in_scope "$base" "$REVIEW_BASE_BRANCHES")
  labeled=$(has_label "$labels" "$HUMAN_REVIEW_LABEL")
  approved=$(has_head_approval "$reviews" "$author" "$head_sha")
  decision=$(decide "$in_scope" "$reviewed_sha" "$risk" "$head_sha" "$labeled" "$approved" "$HUMAN_REVIEW_LABEL")

  echo "Review gate for #$PR_NUMBER at $head_sha: $decision"
  gh api --method POST "repos/$REPOSITORY/statuses/$head_sha" \
    -f state="${decision%%|*}" \
    -f context="$STATUS_CONTEXT" \
    -f description="${decision#*|}" \
    -f target_url="$TARGET_URL" > /dev/null
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
