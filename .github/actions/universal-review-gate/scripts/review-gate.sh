#!/bin/bash
# Sets the review gate commit status on the PR head: green once the AI review has commented on the PR
# and, for PRs carrying the human-review label, a reviewer other than the author approved.
set -euo pipefail

# has_marker_comment <comments_json> <marker>: "true" when any comment body starts with the marker.
has_marker_comment() {
  jq -r --arg marker "$2" 'any(.[]; (.body // "") | startswith($marker))' <<< "$1"
}

# has_label <labels_json> <label>: "true" when the PR carries the label.
has_label() {
  jq -r --arg label "$2" 'any(.[]; .name == $label)' <<< "$1"
}

# has_approval <reviews_json> <author>: "true" when the latest decisive review of any non-author reviewer is APPROVED.
has_approval() {
  jq -r --arg author "$2" '
    [ .[]
      | select(.user.login != $author)
      | select(.state == "APPROVED" or .state == "CHANGES_REQUESTED" or .state == "DISMISSED") ]
    | group_by(.user.login)
    | map(sort_by(.submitted_at) | last)
    | any(.[]; .state == "APPROVED")' <<< "$1"
}

# decide <has_marker> <needs_human> <approved> <label>: prints "state|description" for the commit status.
decide() {
  local has_marker="$1" needs_human="$2" approved="$3" label="$4"

  if [ "$has_marker" != "true" ]; then
    echo "pending|Waiting for the AI review. Comment /review on the PR to run it."
  elif [ "$needs_human" = "true" ] && [ "$approved" != "true" ]; then
    echo "pending|Labeled $label: waiting for an approving review."
  elif [ "$needs_human" = "true" ]; then
    echo "success|AI review done, human review approved."
  else
    echo "success|AI review done."
  fi
}

main() {
  local pr_json comments reviews author sha labels has_marker needs_human approved decision state description

  pr_json=$(gh api "repos/$REPOSITORY/pulls/$PR_NUMBER")
  author=$(jq -r '.user.login' <<< "$pr_json")
  sha="${HEAD_SHA:-$(jq -r '.head.sha' <<< "$pr_json")}"
  labels=$(jq -c '.labels' <<< "$pr_json")
  comments=$(gh api --paginate --slurp "repos/$REPOSITORY/issues/$PR_NUMBER/comments" | jq -c 'add // []')
  reviews=$(gh api --paginate --slurp "repos/$REPOSITORY/pulls/$PR_NUMBER/reviews" | jq -c 'add // []')

  has_marker=$(has_marker_comment "$comments" "$MARKER")
  needs_human=$(has_label "$labels" "$HUMAN_REVIEW_LABEL")
  approved=$(has_approval "$reviews" "$author")
  decision=$(decide "$has_marker" "$needs_human" "$approved" "$HUMAN_REVIEW_LABEL")
  state="${decision%%|*}"
  description="${decision#*|}"

  echo "Review gate for #$PR_NUMBER at $sha: $state ($description)"
  gh api --method POST "repos/$REPOSITORY/statuses/$sha" \
    -f state="$state" \
    -f context="$STATUS_CONTEXT" \
    -f description="$description" \
    -f target_url="$TARGET_URL" > /dev/null
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main
fi
