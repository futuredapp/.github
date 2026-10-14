#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../scripts/feature-review-notify.sh"
}

@test "extract_section: returns the text under the heading up to the next heading" {
  body=$'## Summary\nAdds checkout.\n\n## What to try\n\nOpen the cart and pay with a saved card.\nTry offline too.\n\n## Notes\nNone.'
  result=$(extract_section "$body" "What to try")
  [ "$result" = $'Open the cart and pay with a saved card.\nTry offline too.' ]
}

@test "extract_section: section at the end of the body" {
  body=$'## Summary\nAdds checkout.\n## What to try\nOpen the cart.'
  [ "$(extract_section "$body" "What to try")" = "Open the cart." ]
}

@test "extract_section: keeps level-3 headings inside the section" {
  body=$'## What to try\n### iPhone\nRotate it.\n## Notes'
  [ "$(extract_section "$body" "What to try")" = $'### iPhone\nRotate it.' ]
}

@test "extract_section: handles CRLF bodies from the GitHub UI" {
  body=$'## What to try\r\nOpen the cart.\r\n\r\n## Notes\r\n'
  [ "$(extract_section "$body" "What to try")" = "Open the cart." ]
}

@test "extract_section: empty when the heading is missing" {
  [ "$(extract_section $'## Summary\nText' "What to try")" = "" ]
}

@test "prs_in_range: keeps only PRs merged by a commit in the range" {
  prs='[{"number":1,"mergeCommit":{"oid":"aaa"}},{"number":2,"mergeCommit":{"oid":"bbb"}},{"number":3,"mergeCommit":null}]'
  result=$(prs_in_range "$prs" '["bbb","ccc"]')
  [ "$(jq -c '[.[].number]' <<< "$result")" = "[2]" ]
}

@test "build_payload: lists PRs with their what-to-try text and mentions the reviewer" {
  prs='[{"number":7,"title":"Cart & checkout","url":"https://example.com/7","body":"## What to try\nPay with <card>."}]'
  text=$(build_payload "$prs" "iOS nightly" "<@U123>" "What to try" | jq -r '.text')
  [ "$text" = $'*iOS nightly* is out with 1 finished feature(s) to try in the app, <@U123>:\n• <https://example.com/7|#7 Cart &amp; checkout>\n>Pay with &lt;card&gt;.' ]
}

@test "build_payload: PR without the section is still listed" {
  prs='[{"number":8,"title":"Onboarding","url":"https://example.com/8","body":null}]'
  text=$(build_payload "$prs" "iOS nightly" "" "What to try" | jq -r '.text')
  [ "$text" = $'*iOS nightly* is out with 1 finished feature(s) to try in the app:\n• <https://example.com/8|#8 Onboarding>' ]
}
