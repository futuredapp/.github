#!/bin/bash
# Creates PRs in all consumer repos to bump futuredapp/.github workflow refs.
#
# Usage: .github/scripts/notify-consumer-repos.sh <new-version> [--dry-run]
# Example: .github/scripts/notify-consumer-repos.sh 2.3.0
#
# Requires: gh CLI authenticated with a token that has repo scope across the org.
#
# Environment variables:
#   NOTIFY_REPOS_WHITELIST — space-separated glob patterns matching repo names
#                            (without org prefix). If set, only matching repos
#                            receive PRs. Example: "ios-* android-* kmp-project"

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <new-version> [--dry-run]"
    exit 1
fi

NEW_VERSION="$1"
DRY_RUN="${2:-}"
BRANCH_NAME="housekeep/bump-shared-workflows"
SELF_REPO="futuredapp/.github"

# Detect major version bump → breaking change
PREVIOUS_TAG=$(git tag --sort=-v:refname | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | grep -v "^${NEW_VERSION}$" | head -1)
IS_BREAKING=false
if [ -n "$PREVIOUS_TAG" ]; then
    old_major="${PREVIOUS_TAG%%.*}"
    new_major="${NEW_VERSION%%.*}"
    if [ "$old_major" != "$new_major" ]; then
        IS_BREAKING=true
        echo "Major version bump detected: ${PREVIOUS_TAG} → ${NEW_VERSION}"
    fi
fi

# Cross-platform sed in-place
sedi() {
    if sed --version >/dev/null 2>&1; then
        sed -i -E "$@"  # GNU (Linux)
    else
        sed -i '' -E "$@"  # BSD (macOS)
    fi
}

echo "Searching for consumer repos..."
REPOS=""
page=1
while true; do
    result=$(gh api -X GET "/search/code" \
        -f q="org:futuredapp \"uses: futuredapp/.github\" path:.github/workflows" \
        -f per_page=100 \
        -f page="$page" \
        --jq '.items[].repository.full_name' 2>/dev/null)
    [ -z "$result" ] && break
    REPOS="$REPOS
$result"
    page=$((page + 1))
done
REPOS=$(echo "$REPOS" | sort -u | sed '/^$/d')

# Apply whitelist filter if set
if [ -n "${NOTIFY_REPOS_WHITELIST:-}" ]; then
    FILTERED=""
    for repo in $REPOS; do
        repo_name="${repo#*/}"
        for pattern in $NOTIFY_REPOS_WHITELIST; do
            if [[ "$repo_name" == $pattern ]]; then
                FILTERED="$FILTERED
$repo"
                break
            fi
        done
    done
    REPOS=$(echo "$FILTERED" | sed '/^$/d')
    echo "Whitelist filter applied: $(echo "$REPOS" | wc -l | tr -d ' ') repos match"
fi

created=0
updated=0
skipped=0
failed=0

for repo in $REPOS; do
    # Skip self
    if [ "$repo" = "$SELF_REPO" ]; then
        continue
    fi

    # Check if repo is archived
    is_archived=$(gh api "repos/$repo" --jq '.archived' 2>/dev/null || echo "true")
    if [ "$is_archived" = "true" ]; then
        echo "SKIP (archived): $repo"
        skipped=$((skipped + 1))
        continue
    fi

    # Get default branch
    default_branch=$(gh api "repos/$repo" --jq '.default_branch' 2>/dev/null || echo "")
    if [ -z "$default_branch" ]; then
        echo "SKIP (no access): $repo"
        skipped=$((skipped + 1))
        continue
    fi

    # Check if an open PR already exists for this branch
    existing_pr=$(gh pr list --repo "$repo" --head "$BRANCH_NAME" --state open --json number --jq '.[0].number' 2>/dev/null || echo "")

    # Find workflow files referencing futuredapp/.github
    workflow_files=$(gh api "repos/$repo/contents/.github/workflows" --jq '.[].name' 2>/dev/null || echo "")
    if [ -z "$workflow_files" ]; then
        echo "SKIP (no workflows): $repo"
        skipped=$((skipped + 1))
        continue
    fi

    files_to_update=()
    for wf in $workflow_files; do
        content=$(gh api "repos/$repo/contents/.github/workflows/$wf" --jq '.content' 2>/dev/null | base64 -d 2>/dev/null || echo "")
        if echo "$content" | grep -q 'futuredapp/\.github/'; then
            if ! echo "$content" | grep -q "@${NEW_VERSION}"; then
                files_to_update+=("$wf")
            fi
        fi
    done

    if [ ${#files_to_update[@]} -eq 0 ]; then
        echo "SKIP (already up to date): $repo"
        skipped=$((skipped + 1))
        continue
    fi

    if [ "$DRY_RUN" = "--dry-run" ]; then
        if [ -n "$existing_pr" ]; then
            echo "DRY RUN (update PR #$existing_pr): $repo (${#files_to_update[@]} files: ${files_to_update[*]})"
        else
            echo "DRY RUN (create): $repo (${#files_to_update[@]} files: ${files_to_update[*]})"
        fi
        created=$((created + 1))
        continue
    fi

    # Get the SHA of the default branch HEAD
    base_sha=$(gh api "repos/$repo/git/refs/heads/$default_branch" --jq '.object.sha' 2>/dev/null || echo "")
    if [ -z "$base_sha" ]; then
        echo "FAIL (cannot get HEAD): $repo"
        failed=$((failed + 1))
        continue
    fi

    if [ -n "$existing_pr" ]; then
        # --- Update existing PR ---

        # Reset branch to latest default branch HEAD
        if ! gh api "repos/$repo/git/refs/heads/$BRANCH_NAME" \
            -X PATCH -f sha="$base_sha" -f force=true >/dev/null 2>&1; then
            echo "FAIL (cannot reset branch): $repo"
            failed=$((failed + 1))
            continue
        fi
    else
        # --- Create new branch ---

        if ! gh api "repos/$repo/git/refs" \
            -f "ref=refs/heads/$BRANCH_NAME" \
            -f "sha=$base_sha" >/dev/null 2>&1; then
            echo "FAIL (cannot create branch): $repo"
            failed=$((failed + 1))
            continue
        fi
    fi

    # Update each workflow file on the branch
    update_ok=true
    for wf in "${files_to_update[@]}"; do
        file_info=$(gh api "repos/$repo/contents/.github/workflows/$wf" -f ref="$BRANCH_NAME" --jq '{sha: .sha, content: .content}' 2>/dev/null)
        file_sha=$(echo "$file_info" | jq -r '.sha')
        old_content=$(echo "$file_info" | jq -r '.content' | base64 -d)

        new_content=$(echo "$old_content" | sed -E "s#(futuredapp/\.github/.+)@(main|[0-9]+\.[0-9]+\.[0-9]+)#\1@${NEW_VERSION}#g")
        encoded=$(echo "$new_content" | base64)

        if ! gh api "repos/$repo/contents/.github/workflows/$wf" \
            -X PUT \
            -f "message=Bump shared workflow refs to ${NEW_VERSION}" \
            -f "content=$encoded" \
            -f "sha=$file_sha" \
            -f "branch=$BRANCH_NAME" >/dev/null 2>&1; then
            echo "FAIL (cannot update $wf): $repo"
            update_ok=false
            break
        fi
    done

    if [ "$update_ok" = false ]; then
        failed=$((failed + 1))
        continue
    fi

    # Build PR title and body
    pr_title="Bump shared workflows to ${NEW_VERSION}"
    if [ "$IS_BREAKING" = true ]; then
        pr_title="⚠️ $pr_title (breaking changes)"
    fi

    pr_body="## Summary

Updates \`futuredapp/.github\` workflow refs from current version to \`@${NEW_VERSION}\`.

**Updated files:** ${files_to_update[*]}"

    if [ "$IS_BREAKING" = true ]; then
        pr_body="$pr_body

> [!CAUTION]
> **This is a major version bump (\`${PREVIOUS_TAG}\` → \`${NEW_VERSION}\`).** This release may contain breaking changes. Review carefully before merging."
    fi

    pr_body="$pr_body

See [release notes](https://github.com/futuredapp/.github/releases/tag/${NEW_VERSION}) for what changed.

---
*Automated PR created by [futuredapp/.github](https://github.com/futuredapp/.github)*"

    if [ -n "$existing_pr" ]; then
        # --- Update existing PR ---

        gh pr edit "$existing_pr" \
            --repo "$repo" \
            --title "$pr_title" \
            --body "$pr_body" >/dev/null 2>&1

        # Convert to draft if breaking
        if [ "$IS_BREAKING" = true ]; then
            gh pr ready --undo --repo "$repo" "$existing_pr" 2>/dev/null || true
        fi

        echo "UPDATED: $repo → PR #$existing_pr"
        updated=$((updated + 1))
    else
        # --- Create new PR ---

        create_args=(
            --repo "$repo"
            --head "$BRANCH_NAME"
            --base "$default_branch"
            --title "$pr_title"
            --body "$pr_body"
        )
        if [ "$IS_BREAKING" = true ]; then
            create_args+=(--draft)
        fi

        pr_url=$(gh pr create "${create_args[@]}" 2>&1 || echo "")

        if [ -n "$pr_url" ]; then
            echo "CREATED: $repo → $pr_url"
            created=$((created + 1))
        else
            echo "FAIL (cannot create PR): $repo"
            failed=$((failed + 1))
        fi
    fi
done

echo ""
echo "Done. Created: $created, Updated: $updated, Skipped: $skipped, Failed: $failed"
