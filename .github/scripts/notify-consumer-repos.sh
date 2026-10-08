#!/bin/bash
# Creates PRs in all consumer repos to bump futuredapp/.github workflow refs.
#
# Usage: .github/scripts/notify-consumer-repos.sh <new-version> [--dry-run]
# Example: .github/scripts/notify-consumer-repos.sh 2.3.0
#
# Requires: gh CLI authenticated with a token that has repo scope across the org.
#
# Environment variables:
#   NOTIFY_REPOS             — space-separated full repo names (org/name). If set,
#                              the GitHub code search is skipped and only these repos
#                              are processed. Useful for re-running a few failed repos.
#   NOTIFY_REPOS_WHITELIST   — space-separated glob patterns matching repo names
#                              (without org prefix). If set, only matching repos
#                              receive PRs. Example: "ios-* android-* kmp-project"
#   NOTIFY_RETRY_MAX_ATTEMPTS — how many retry passes to run over repos that failed
#                              (default 10). Each pass waits with exponential backoff.
#   NOTIFY_RETRY_BASE_DELAY  — delay in seconds before the first retry pass (default 2).
#                              Doubles with every pass.
#   NOTIFY_RETRY_MAX_DELAY   — upper bound for the backoff delay in seconds (default 300).

set -euo pipefail

BRANCH_NAME="housekeep/bump-shared-workflows"
SELF_REPO="futuredapp/.github"

RETRY_MAX_ATTEMPTS="${NOTIFY_RETRY_MAX_ATTEMPTS:-10}"
RETRY_BASE_DELAY="${NOTIFY_RETRY_BASE_DELAY:-2}"
RETRY_MAX_DELAY="${NOTIFY_RETRY_MAX_DELAY:-300}"

# Last stderr line of the most recent failed gh call, shown next to FAIL messages.
LAST_ERROR=""
STDERR_FILE=""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Backoff delay (seconds) before retry pass number $1 (1-based):
# base * 2^(attempt-1), capped at RETRY_MAX_DELAY.
retry_delay() {
    local attempt="$1"
    local delay=$(( RETRY_BASE_DELAY * (1 << (attempt - 1)) ))
    if [ "$delay" -gt "$RETRY_MAX_DELAY" ]; then
        delay="$RETRY_MAX_DELAY"
    fi
    echo "$delay"
}

# Remember the last non-empty stderr line of a failed gh call.
capture_last_error() {
    LAST_ERROR=$(grep -v '^$' "$STDERR_FILE" | tail -1 || true)
}

# Run a gh command whose output we do not need. Returns gh's exit code and
# records the error message on failure instead of silently discarding it.
gh_run() {
    LAST_ERROR=""
    if gh "$@" >/dev/null 2>"$STDERR_FILE"; then
        return 0
    fi
    capture_last_error
    return 1
}

# Print a FAIL line for the current repo, including the API error if known.
report_failure() {
    local reason="$1" repo="$2"
    if [ -n "$LAST_ERROR" ]; then
        echo "FAIL ($reason): $repo — $LAST_ERROR"
    else
        echo "FAIL ($reason): $repo"
    fi
}

# Decode a base64 "content" field from the Contents API; empty on failure.
decode_content() {
    local raw="$1"
    if [ -n "$raw" ]; then
        echo "$raw" | base64 -d 2>/dev/null || true
    fi
}

# Replace all futuredapp/.github refs (@main or @x.y.z) with @NEW_VERSION.
bump_refs() {
    sed -E "s#(futuredapp/\.github/.+)@(main|[0-9]+\.[0-9]+\.[0-9]+)#\1@${NEW_VERSION}#g"
}

# ---------------------------------------------------------------------------
# Repo discovery
# ---------------------------------------------------------------------------

discover_repos() {
    if [ -n "${NOTIFY_REPOS:-}" ]; then
        echo "Using explicit repo list from NOTIFY_REPOS" >&2
        echo "$NOTIFY_REPOS" | tr ' ' '\n' | sort -u | sed '/^$/d'
        return
    fi

    echo "Searching for consumer repos..." >&2
    local repos="" page=1 result
    while true; do
        result=$(gh api -X GET "/search/code" \
            -f q="org:futuredapp \"uses: futuredapp/.github\" path:.github/workflows" \
            -f per_page=100 \
            -f page="$page" \
            --jq '.items[].repository.full_name' 2>/dev/null || true)
        [ -z "$result" ] && break
        repos="$repos
$result"
        page=$((page + 1))
    done
    echo "$repos" | sort -u | sed '/^$/d'
}

apply_whitelist() {
    local repos="$1" filtered="" repo repo_name pattern count
    local whitelist
    whitelist=$(echo "$NOTIFY_REPOS_WHITELIST" | tr -d '\r')
    set -f  # disable file glob expansion so patterns like "ios-*" stay literal
    for repo in $repos; do
        repo_name="${repo#*/}"
        for pattern in $whitelist; do
            if [[ "$repo_name" == $pattern ]]; then
                filtered="$filtered
$repo"
                break
            fi
        done
    done
    set +f
    repos=$(echo "$filtered" | sed '/^$/d')
    count=$(echo "$repos" | grep -c . 2>/dev/null || true)
    echo "Whitelist applied: ${count:-0} repos match" >&2
    echo "$repos"
}

# ---------------------------------------------------------------------------
# Per-repo processing
# ---------------------------------------------------------------------------

# Prepare the PR branch for an existing open PR: merge the default branch into it.
# Force-resetting the branch to base HEAD would leave the PR with zero commits and
# GitHub auto-closes such PRs, so we only ever add commits on top.
# On merge conflict the branch is recreated from scratch; GitHub closes the stale PR
# once its head ref is deleted and a fresh PR is created by the caller.
# Sets existing_pr="" when the caller must create a new PR.
prepare_existing_branch() {
    local repo="$1" default_branch="$2" base_sha="$3"

    if gh_run api "repos/$repo/merges" -f "base=$BRANCH_NAME" -f "head=$default_branch"; then
        return 0
    fi

    echo "  merge of $default_branch into $BRANCH_NAME failed ($LAST_ERROR), recreating branch"
    if ! gh_run api -X DELETE "repos/$repo/git/refs/heads/$BRANCH_NAME"; then
        report_failure "cannot delete branch" "$repo"
        return 1
    fi
    if ! gh_run api "repos/$repo/git/refs" -f "ref=refs/heads/$BRANCH_NAME" -f "sha=$base_sha"; then
        report_failure "cannot recreate branch" "$repo"
        return 1
    fi
    existing_pr=""
    return 0
}

# Create the PR branch at base HEAD, resetting a leftover branch from a previous run.
prepare_new_branch() {
    local repo="$1" base_sha="$2"

    if gh_run api "repos/$repo/git/refs" -f "ref=refs/heads/$BRANCH_NAME" -f "sha=$base_sha"; then
        return 0
    fi
    if gh_run api "repos/$repo/git/refs/heads/$BRANCH_NAME" -X PATCH -f sha="$base_sha" -F force=true; then
        return 0
    fi
    report_failure "cannot create branch" "$repo"
    return 1
}

# Commit bumped workflow files to the PR branch. Files already at NEW_VERSION
# on the branch (e.g. from a previous attempt) are left untouched.
update_workflow_files() {
    local repo="$1"; shift
    local wf file_data file_sha old_content new_content encoded

    for wf in "$@"; do
        file_data=$(gh api "repos/$repo/contents/.github/workflows/$wf?ref=$BRANCH_NAME" \
            --jq '{sha: .sha, content: .content}' 2>"$STDERR_FILE" || echo "{}")
        file_sha=$(echo "$file_data" | jq -r '.sha // empty')
        if [ -z "$file_sha" ]; then
            capture_last_error
            report_failure "cannot read $wf" "$repo"
            return 1
        fi

        old_content=$(decode_content "$(echo "$file_data" | jq -r '.content // empty')")
        new_content=$(echo "$old_content" | bump_refs)
        if [ "$new_content" = "$old_content" ]; then
            continue
        fi
        encoded=$(echo "$new_content" | base64 | tr -d '\n')

        if ! gh_run api "repos/$repo/contents/.github/workflows/$wf" \
            -X PUT \
            -f "message=Bump shared workflow refs to ${NEW_VERSION}" \
            -f "content=$encoded" \
            -f "sha=$file_sha" \
            -f "branch=$BRANCH_NAME"; then
            report_failure "cannot update $wf" "$repo"
            return 1
        fi
    done
}

build_pr_body() {
    local files="$1"
    local body="## Summary

Updates \`futuredapp/.github\` workflow refs from current version to \`@${NEW_VERSION}\`.

**Updated files:** ${files}"

    if [ "$IS_BREAKING" = true ]; then
        body="$body

> [!CAUTION]
> **This is a major version bump (\`${PREVIOUS_TAG}\` → \`${NEW_VERSION}\`).** This release may contain breaking changes. Review carefully before merging."
    fi

    echo "$body

See [changelog](https://futuredapp.github.io/.github/${NEW_VERSION}/) for what changed.

---
*Automated PR created by [futuredapp/.github](https://github.com/futuredapp/.github)*"
}

# Process one repo. Sets RESULT to created | updated | skipped | failed.
process_repo() {
    local repo="$1"
    RESULT="failed"

    local is_archived default_branch existing_pr workflow_files wf raw_content content
    local base_sha pr_title pr_body pr_url pr_state

    is_archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "true")
    if [ "$is_archived" = "true" ]; then
        echo "SKIP (archived): $repo"
        RESULT="skipped"
        return
    fi

    default_branch=$(gh api "repos/$repo" --jq '.default_branch' 2>/dev/null || echo "")
    if [ -z "$default_branch" ]; then
        echo "SKIP (no access): $repo"
        RESULT="skipped"
        return
    fi

    existing_pr=$(gh pr list --repo "$repo" --head "$BRANCH_NAME" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")

    workflow_files=$(gh api "repos/$repo/contents/.github/workflows" --jq '.[].name' 2>/dev/null || echo "")
    if [ -z "$workflow_files" ]; then
        echo "SKIP (no workflows): $repo"
        RESULT="skipped"
        return
    fi

    local files_to_update=()
    for wf in $workflow_files; do
        raw_content=$(gh api "repos/$repo/contents/.github/workflows/$wf" --jq '.content' 2>/dev/null || echo "")
        content=$(decode_content "$raw_content")
        if echo "$content" | grep -q 'futuredapp/\.github/'; then
            if ! echo "$content" | grep -q "@${NEW_VERSION}"; then
                files_to_update+=("$wf")
            fi
        fi
    done

    if [ ${#files_to_update[@]} -eq 0 ]; then
        echo "SKIP (already up to date): $repo"
        RESULT="skipped"
        return
    fi

    if [ "$DRY_RUN" = "--dry-run" ]; then
        if [ -n "$existing_pr" ]; then
            echo "DRY RUN (update PR #$existing_pr): $repo (${#files_to_update[@]} files: ${files_to_update[*]})"
        else
            echo "DRY RUN (create): $repo (${#files_to_update[@]} files: ${files_to_update[*]})"
        fi
        RESULT="created"
        return
    fi

    base_sha=$(gh api "repos/$repo/git/refs/heads/$default_branch" --jq '.object.sha' 2>"$STDERR_FILE" || echo "")
    if [ -z "$base_sha" ]; then
        capture_last_error
        report_failure "cannot get HEAD" "$repo"
        return
    fi

    if [ -n "$existing_pr" ]; then
        prepare_existing_branch "$repo" "$default_branch" "$base_sha" || return
    else
        prepare_new_branch "$repo" "$base_sha" || return
    fi

    update_workflow_files "$repo" "${files_to_update[@]}" || return

    pr_title="Bump shared workflows to ${NEW_VERSION}"
    if [ "$IS_BREAKING" = true ]; then
        pr_title="⚠️ $pr_title (breaking changes)"
    fi
    pr_body=$(build_pr_body "${files_to_update[*]}")

    if [ -n "$existing_pr" ]; then
        if ! gh_run pr edit "$existing_pr" --repo "$repo" --title "$pr_title" --body "$pr_body"; then
            report_failure "cannot edit PR #$existing_pr" "$repo"
            return
        fi
        if [ "$IS_BREAKING" = true ]; then
            gh pr ready --undo --repo "$repo" "$existing_pr" 2>/dev/null || true
        fi

        # Guard against reporting success on a PR GitHub closed underneath us.
        pr_state=$(gh pr view "$existing_pr" --repo "$repo" --json state --jq '.state' 2>/dev/null || echo "")
        if [ "$pr_state" != "OPEN" ]; then
            LAST_ERROR="PR state is ${pr_state:-unknown}"
            report_failure "PR #$existing_pr not open" "$repo"
            return
        fi

        echo "UPDATED: $repo → PR #$existing_pr"
        RESULT="updated"
        return
    fi

    local create_args=(
        --repo "$repo"
        --head "$BRANCH_NAME"
        --base "$default_branch"
        --title "$pr_title"
        --body "$pr_body"
    )
    if [ "$IS_BREAKING" = true ]; then
        create_args+=(--draft)
    fi

    if ! pr_url=$(gh pr create "${create_args[@]}" 2>"$STDERR_FILE"); then
        capture_last_error
        report_failure "cannot create PR" "$repo"
        return
    fi

    echo "CREATED: $repo → $pr_url"
    RESULT="created"
}

# Process a repo and update the counters. Returns 1 when the repo failed.
run_repo() {
    process_repo "$1"
    case "$RESULT" in
        created) created=$((created + 1)) ;;
        updated) updated=$((updated + 1)) ;;
        skipped) skipped=$((skipped + 1)) ;;
        *) return 1 ;;
    esac
    return 0
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

main() {
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <new-version> [--dry-run]"
        exit 1
    fi

    NEW_VERSION="$1"
    DRY_RUN="${2:-}"

    STDERR_FILE=$(mktemp)
    trap 'rm -f "$STDERR_FILE"' EXIT

    # Detect major version bump → breaking change
    PREVIOUS_TAG=$(git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | grep -v "^${NEW_VERSION}$" | head -1 || true)
    IS_BREAKING=false
    if [ -n "$PREVIOUS_TAG" ]; then
        local old_major="${PREVIOUS_TAG%%.*}"
        local new_major="${NEW_VERSION%%.*}"
        if [ "$old_major" != "$new_major" ]; then
            IS_BREAKING=true
            echo "Major version bump detected: ${PREVIOUS_TAG} → ${NEW_VERSION}"
        fi
    fi

    local repos
    repos=$(discover_repos)
    if [ -n "${NOTIFY_REPOS_WHITELIST:-}" ]; then
        repos=$(apply_whitelist "$repos")
    fi
    repos=$(echo "$repos" | grep -vx "$SELF_REPO" || true)

    created=0
    updated=0
    skipped=0

    # Disable set -e for the repo loop — errors are handled explicitly per repo
    set +eo pipefail

    local repo
    local failed_repos=()
    for repo in $repos; do
        run_repo "$repo" || failed_repos+=("$repo")
    done

    # Retry failed repos with exponential backoff (covers transient API/GitHub outages).
    local attempt=0 delay
    local still_failed=()
    while [ ${#failed_repos[@]} -gt 0 ] && [ "$attempt" -lt "$RETRY_MAX_ATTEMPTS" ]; do
        attempt=$((attempt + 1))
        delay=$(retry_delay "$attempt")
        echo ""
        echo "Retry ${attempt}/${RETRY_MAX_ATTEMPTS}: ${#failed_repos[@]} repo(s) failed, waiting ${delay}s..."
        sleep "$delay"

        still_failed=()
        for repo in "${failed_repos[@]}"; do
            run_repo "$repo" || still_failed+=("$repo")
        done
        failed_repos=(${still_failed[@]+"${still_failed[@]}"})
    done

    local failed=${#failed_repos[@]}
    echo ""
    echo "Done. Created: $created, Updated: $updated, Skipped: $skipped, Failed: $failed"
    if [ "$failed" -gt 0 ]; then
        echo "Still failing after ${attempt} retries: ${failed_repos[*]}"
    fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main "$@"
fi
