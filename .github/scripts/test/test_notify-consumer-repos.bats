#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../notify-consumer-repos.sh"
REPO="futuredapp/demo-repo"
BRANCH="housekeep/bump-shared-workflows"

setup() {
  export PATH="$BATS_TEST_DIRNAME/mocks:$PATH"
  export GH_MOCK_LOG="$BATS_TEST_TMPDIR/gh.log"
  export GH_MOCK_STATE_DIR="$BATS_TEST_TMPDIR/state"
  mkdir -p "$GH_MOCK_STATE_DIR"
  : > "$GH_MOCK_LOG"

  export NOTIFY_REPOS="$REPO"
  export NOTIFY_RETRY_BASE_DELAY=0
  export NOTIFY_RETRY_MAX_ATTEMPTS=3
  unset NOTIFY_REPOS_WHITELIST
  unset GH_MOCK_EXISTING_PR GH_MOCK_PR_STATE GH_MOCK_BRANCH_EXISTS GH_MOCK_MERGE_FAIL \
        GH_MOCK_PUT_FAIL_TIMES GH_MOCK_PUT_FAIL_REPO GH_MOCK_PR_CREATE_FAIL GH_MOCK_BRANCH_FILE_VERSION
}

run_script() {
  run bash "$SCRIPT" 2.9.9 "$@"
}

gh_called() {
  grep -q -- "$1" "$GH_MOCK_LOG"
}

# --- backoff -----------------------------------------------------------------

@test "retry delay doubles from the base delay and is capped" {
  NOTIFY_RETRY_BASE_DELAY=2 NOTIFY_RETRY_MAX_DELAY=300 source "$SCRIPT"
  delays=""
  for attempt in 1 2 3 4 5 6 7 8 9 10; do
    delays="$delays $(retry_delay "$attempt")"
  done
  [ "$delays" = " 2 4 8 16 32 64 128 256 300 300" ]
}

# --- create path -------------------------------------------------------------

@test "creates a PR when no bump PR is open" {
  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"CREATED: $REPO → https://github.com/futuredapp/demo-repo/pull/42"* ]]
  [[ "$output" == *"Done. Created: 1, Updated: 0, Skipped: 0, Failed: 0"* ]]
  gh_called "api repos/$REPO/git/refs -f ref=refs/heads/$BRANCH"
  gh_called "contents/.github/workflows/ci.yml -X PUT"
  ! gh_called "contents/.github/workflows/lint.yml -X PUT"
  ! gh_called "repos/$REPO/merges"
}

@test "reuses a leftover branch by resetting it to base HEAD" {
  export GH_MOCK_BRANCH_EXISTS=1
  run_script
  [[ "$output" == *"CREATED: $REPO"* ]]
  gh_called "api repos/$REPO/git/refs/heads/$BRANCH -X PATCH -f sha=basesha123 -F force=true"
}

@test "failed PR creation is reported as FAIL with the gh error message" {
  export GH_MOCK_PR_CREATE_FAIL=1
  run_script
  [[ "$output" != *"CREATED"* ]]
  [[ "$output" == *"FAIL (cannot create PR): $REPO — gh: pull request create failed"* ]]
  [[ "$output" == *"Failed: 1"* ]]
}

# --- update path -------------------------------------------------------------

@test "updates an open PR by merging the default branch instead of force-resetting" {
  export GH_MOCK_EXISTING_PR=7
  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"UPDATED: $REPO → PR #7"* ]]
  [[ "$output" == *"Created: 0, Updated: 1, Skipped: 0, Failed: 0"* ]]
  gh_called "api repos/$REPO/merges -f base=$BRANCH -f head=main"
  gh_called "contents/.github/workflows/ci.yml -X PUT"
  gh_called "pr edit 7 --repo $REPO"
  ! gh_called "-X PATCH"
  ! gh_called "pr create"
}

@test "merge conflict recreates the branch and opens a fresh PR" {
  export GH_MOCK_EXISTING_PR=7
  export GH_MOCK_MERGE_FAIL=1
  run_script
  [[ "$output" == *"recreating branch"* ]]
  [[ "$output" == *"CREATED: $REPO"* ]]
  [[ "$output" == *"Created: 1, Updated: 0, Skipped: 0, Failed: 0"* ]]
  gh_called "api -X DELETE repos/$REPO/git/refs/heads/$BRANCH"
  gh_called "api repos/$REPO/git/refs -f ref=refs/heads/$BRANCH -f sha=basesha123"
  gh_called "pr create"
  ! gh_called "pr edit"
}

@test "update is a failure when the PR is no longer open" {
  export GH_MOCK_EXISTING_PR=7
  export GH_MOCK_PR_STATE=CLOSED
  run_script
  [[ "$output" != *"UPDATED"* ]]
  [[ "$output" == *"FAIL (PR #7 not open): $REPO — PR state is CLOSED"* ]]
  [[ "$output" == *"Failed: 1"* ]]
}

@test "files already bumped on the branch are not rewritten" {
  export GH_MOCK_EXISTING_PR=7
  export GH_MOCK_BRANCH_FILE_VERSION=2.9.9
  run_script
  [[ "$output" == *"UPDATED: $REPO → PR #7"* ]]
  ! gh_called "-X PUT"
}

# --- retries -----------------------------------------------------------------

@test "transient write failures are retried with backoff until they succeed" {
  export GH_MOCK_PUT_FAIL_TIMES=2
  export NOTIFY_RETRY_MAX_ATTEMPTS=5
  run_script
  [ "$status" -eq 0 ]
  [[ "$output" == *"FAIL (cannot update ci.yml): $REPO — gh: HTTP 502"* ]]
  [[ "$output" == *"Retry 1/5: 1 repo(s) failed, waiting 0s..."* ]]
  [[ "$output" == *"Retry 2/5: 1 repo(s) failed"* ]]
  [[ "$output" != *"Retry 3/5"* ]]
  [[ "$output" == *"CREATED: $REPO"* ]]
  [[ "$output" == *"Done. Created: 1, Updated: 0, Skipped: 0, Failed: 0"* ]]
  [ "$(grep -c -- '-X PUT' "$GH_MOCK_LOG")" -eq 3 ]
}

@test "gives up after the maximum number of retries" {
  export GH_MOCK_PUT_FAIL_TIMES=-1
  run_script
  [[ "$output" == *"Retry 3/3"* ]]
  [[ "$output" != *"Retry 4/3"* ]]
  [[ "$output" == *"Done. Created: 0, Updated: 0, Skipped: 0, Failed: 1"* ]]
  [[ "$output" == *"Still failing after 3 retries: $REPO"* ]]
  [ "$(echo "$output" | grep -c 'FAIL (cannot update ci.yml)')" -eq 4 ]
}

@test "only failed repos are retried" {
  export NOTIFY_REPOS="futuredapp/healthy-repo $REPO"
  export GH_MOCK_PUT_FAIL_TIMES=-1
  export GH_MOCK_PUT_FAIL_REPO="$REPO"
  export NOTIFY_RETRY_MAX_ATTEMPTS=1
  run_script
  [[ "$output" == *"Done. Created: 1, Updated: 0, Skipped: 0, Failed: 1"* ]]
  [ "$(grep -c 'repos/futuredapp/healthy-repo/git/refs -f ref=' "$GH_MOCK_LOG")" -eq 1 ]
  [ "$(grep -c "repos/$REPO/git/refs -f ref=" "$GH_MOCK_LOG")" -eq 2 ]
}

# --- misc --------------------------------------------------------------------

@test "the shared workflows repo itself is never processed" {
  export NOTIFY_REPOS="futuredapp/.github $REPO"
  run_script
  [[ "$output" == *"Done. Created: 1, Updated: 0, Skipped: 0, Failed: 0"* ]]
  ! gh_called "repos/futuredapp/.github"
}

@test "dry run reports planned changes without writing anything" {
  run_script --dry-run
  [[ "$output" == *"DRY RUN (create): $REPO (1 files: ci.yml)"* ]]
  ! gh_called "-X PUT"
  ! gh_called "pr create"
  ! gh_called "git/refs -f ref="
}
