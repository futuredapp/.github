#!/usr/bin/env bash
set -euo pipefail

# Publish CodeCharta snapshots to the data repo specified via DATA_REPO env.
# Invoked by the universal-codecharta-publish composite action.
#
# Inputs (env, set by action.yml from action inputs):
#   CODECHARTA_PUBLISH_MODE     One of: preview, history, bulk-history,
#                               delete-preview, set-latest.
#   PROJECT_NAME                Folder name under `projects/`.
#   DATA_REPO                   `<owner>/<name>` of the data repository.
#   DATA_REPO_BRANCH            Branch to push to (default: main).
#   CODEBASE_ARCHITECTURES_TOKEN
#                               Write-scoped token for the data repo.
#   PR_NUMBER                   Pull-request number (preview/delete-preview).
#   STEM                        `pr-<N>` or `merge-<short-sha>` (history mode).
#   DATE                        `YYYY-MM-DD` (history mode).
#   SOURCE_CC_PATH              Absolute local path to .cc.json.gz to publish.
#   SOURCE_CG_PATH              Absolute local path to .cg.json to publish.
#   SOURCE_META_PATH            Optional absolute local path to .meta.json.
#   SNAPSHOTS_DIR               Absolute path to dir of historical snapshots
#                               (bulk-history mode).

require_env() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
        echo "missing required env: ${name}" >&2
        exit 64
    fi
}

require_env CODECHARTA_PUBLISH_MODE
require_env PROJECT_NAME
require_env DATA_REPO
require_env CODEBASE_ARCHITECTURES_TOKEN

# Validate PROJECT_NAME — used unquoted in path construction (e.g.
# "projects/${PROJECT_NAME}/previews/…"). A value like `../foo` would let the
# script write outside the projects/ tree. Restrict to a safe character set
# AND reject pure-dot values which the regex accepts but are still traversal:
# `PROJECT_NAME=..` makes PROJECT_DIR `projects/..` (i.e. the data repo root).
if [[ ! "${PROJECT_NAME}" =~ ^[A-Za-z0-9._-]+$ ]] || [[ "${PROJECT_NAME}" == "." || "${PROJECT_NAME}" == ".." ]]; then
    echo "PROJECT_NAME must match [A-Za-z0-9._-]+ and not be '.' or '..' (got '${PROJECT_NAME}')" >&2
    exit 64
fi

# Validate DATA_REPO — interpolated into the clone URL. Shell-quoting prevents
# command injection, but an unconstrained value can still target unintended
# repositories. Restrict to <owner>/<name> with the same safe charset.
if [[ ! "${DATA_REPO}" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]; then
    echo "DATA_REPO must match <owner>/<name> (got '${DATA_REPO}')" >&2
    exit 64
fi

DATA_REPO_BRANCH="${DATA_REPO_BRANCH:-main}"
MODE="${CODECHARTA_PUBLISH_MODE}"

case "${MODE}" in
    preview | delete-preview)
        require_env PR_NUMBER
        if [[ ! "${PR_NUMBER}" =~ ^[0-9]+$ ]]; then
            echo "${MODE}: PR_NUMBER must be numeric (got '${PR_NUMBER}')" >&2
            exit 64
        fi
        ;;
    history)
        require_env STEM
        require_env DATE
        if [[ ! "${STEM}" =~ ^(pr-[0-9]+|merge-[0-9a-f]{7,})$ ]]; then
            echo "${MODE}: STEM must match 'pr-<N>' or 'merge-<sha>' (got '${STEM}')" >&2
            exit 64
        fi
        if [[ ! "${DATE}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            echo "${MODE}: DATE must be YYYY-MM-DD (got '${DATE}')" >&2
            exit 64
        fi
        ;;
    bulk-history)
        require_env SNAPSHOTS_DIR
        if [[ ! -d "${SNAPSHOTS_DIR}" ]]; then
            echo "${MODE}: SNAPSHOTS_DIR must be a directory (got '${SNAPSHOTS_DIR}')" >&2
            exit 64
        fi
        ;;
    set-latest)
        # No required args; picks newest history entry by lexicographic sort.
        ;;
    *)
        echo "Unknown CODECHARTA_PUBLISH_MODE: '${MODE}'" >&2
        echo "Expected one of: preview, history, bulk-history, delete-preview, set-latest" >&2
        exit 64
        ;;
esac

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

DATA_REPO_NAME="${DATA_REPO##*/}"
DATA_REPO_DIR="${WORK_DIR}/${DATA_REPO_NAME}"

echo "Cloning ${DATA_REPO}…"
git clone --depth=1 --branch "${DATA_REPO_BRANCH}" \
    "https://x-access-token:${CODEBASE_ARCHITECTURES_TOKEN}@github.com/${DATA_REPO}.git" \
    "${DATA_REPO_DIR}"

cd "${DATA_REPO_DIR}"
git config user.email "codecharta-bot@users.noreply.github.com"
git config user.name "codecharta-bot"
git remote set-url origin "https://x-access-token:${CODEBASE_ARCHITECTURES_TOKEN}@github.com/${DATA_REPO}.git"

PROJECT_DIR="projects/${PROJECT_NAME}"
mkdir -p "${PROJECT_DIR}/previews" "${PROJECT_DIR}/history"

apply_change() {
    case "${MODE}" in
        preview)
            require_env SOURCE_CC_PATH
            require_env SOURCE_CG_PATH
            cp "${SOURCE_CC_PATH}" "${PROJECT_DIR}/previews/pr-${PR_NUMBER}.cc.json.gz"
            cp "${SOURCE_CG_PATH}" "${PROJECT_DIR}/previews/pr-${PR_NUMBER}.cg.json"
            # Mirror the meta sidecar OR explicitly remove it when source is
            # missing. Without the removal a previous run's stale meta (e.g.
            # an older PR title before a rename) would persist.
            if [[ -n "${SOURCE_META_PATH:-}" && -f "${SOURCE_META_PATH}" ]]; then
                cp "${SOURCE_META_PATH}" "${PROJECT_DIR}/previews/pr-${PR_NUMBER}.meta.json"
            else
                rm -f "${PROJECT_DIR}/previews/pr-${PR_NUMBER}.meta.json"
            fi
            ;;
        history)
            require_env SOURCE_CC_PATH
            require_env SOURCE_CG_PATH
            local basename="${DATE}-${STEM}"
            cp "${SOURCE_CC_PATH}" "${PROJECT_DIR}/history/${basename}.cc.json.gz"
            cp "${SOURCE_CG_PATH}" "${PROJECT_DIR}/history/${basename}.cg.json"
            # As with preview: mirror or actively remove. A new history entry
            # with no source meta should NOT inherit a stale per-entry meta
            # from a prior write, and the latest.* pointers below must follow.
            if [[ -n "${SOURCE_META_PATH:-}" && -f "${SOURCE_META_PATH}" ]]; then
                cp "${SOURCE_META_PATH}" "${PROJECT_DIR}/history/${basename}.meta.json"
            else
                rm -f "${PROJECT_DIR}/history/${basename}.meta.json"
            fi
            cp "${PROJECT_DIR}/history/${basename}.cc.json.gz" "${PROJECT_DIR}/history/latest.cc.json.gz"
            cp "${PROJECT_DIR}/history/${basename}.cg.json"    "${PROJECT_DIR}/history/latest.cg.json"
            if [[ -f "${PROJECT_DIR}/history/${basename}.meta.json" ]]; then
                cp "${PROJECT_DIR}/history/${basename}.meta.json" "${PROJECT_DIR}/history/latest.meta.json"
            else
                rm -f "${PROJECT_DIR}/history/latest.meta.json"
            fi
            ;;
        bulk-history)
            # Iterate over <project>-<date>-<stem>.cc.json.gz files. Idempotent
            # per entry: skip files that already exist in the data repo.
            shopt -s nullglob
            local cc base rest entry_date entry_stem entry_cc entry_meta
            local total=0
            local copied=0
            for cc in "${SNAPSHOTS_DIR}/${PROJECT_NAME}"-*.cc.json.gz; do
                total=$(( total + 1 ))
                base="$(basename "${cc}" .cc.json.gz)"
                rest="${base#${PROJECT_NAME}-}"
                if [[ ! "${rest}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-((pr|merge)-[0-9a-f]+)$ ]]; then
                    echo "Skipping unrecognised filename: ${base}" >&2
                    continue
                fi
                entry_date="${BASH_REMATCH[1]}"
                entry_stem="${BASH_REMATCH[2]}"
                local entry_basename="${entry_date}-${entry_stem}"
                local entry_target_cc="${PROJECT_DIR}/history/${entry_basename}.cc.json.gz"
                local entry_target_meta="${PROJECT_DIR}/history/${entry_basename}.meta.json"
                entry_cc="${cc}"
                entry_meta="${cc%.cc.json.gz}.meta.json"

                if [[ ! -f "${entry_target_cc}" ]]; then
                    cp "${entry_cc}" "${entry_target_cc}"
                    copied=$(( copied + 1 ))
                fi
                if [[ -f "${entry_meta}" && ! -f "${entry_target_meta}" ]]; then
                    cp "${entry_meta}" "${entry_target_meta}"
                fi
            done
            echo "Bulk-history scanned ${total} entries; wrote ${copied} new history files."
            ;;
        delete-preview)
            rm -f "${PROJECT_DIR}/previews/pr-${PR_NUMBER}.cc.json.gz" \
                  "${PROJECT_DIR}/previews/pr-${PR_NUMBER}.cg.json" \
                  "${PROJECT_DIR}/previews/pr-${PR_NUMBER}.meta.json"
            ;;
        set-latest)
            local newest
            newest=$(ls -1 "${PROJECT_DIR}/history/" 2>/dev/null \
                     | grep -E '\.cc\.json\.gz$' \
                     | grep -v '^latest' \
                     | sort -r \
                     | head -1 || true)
            if [[ -z "${newest}" ]]; then
                echo "No history entries found; nothing to set as latest."
                return
            fi
            local base="${newest%.cc.json.gz}"
            cp "${PROJECT_DIR}/history/${newest}" "${PROJECT_DIR}/history/latest.cc.json.gz"
            # Update the cg/meta sidecars only when the selected newest entry
            # has them. Otherwise leave the existing latest.* alone — backfill
            # entries intentionally omit `.cg.json` (DependaCharta isn't run
            # per historical commit), and we'd rather keep a graph from an
            # older entry than break the picker's DependaCharta view entirely.
            # `latest.meta.json` follows the same policy: rebase-merge history
            # entries have no PR to query, but a prior PR-merge entry's title
            # is more useful than no title at all.
            if [[ -f "${PROJECT_DIR}/history/${base}.cg.json" ]]; then
                cp "${PROJECT_DIR}/history/${base}.cg.json" "${PROJECT_DIR}/history/latest.cg.json"
            fi
            if [[ -f "${PROJECT_DIR}/history/${base}.meta.json" ]]; then
                cp "${PROJECT_DIR}/history/${base}.meta.json" "${PROJECT_DIR}/history/latest.meta.json"
            fi
            ;;
    esac
}

apply_change

if [[ -f scripts/build-manifest.mjs ]]; then
    echo "Rebuilding manifest…"
    node scripts/build-manifest.mjs
fi

# Stage everything first so untracked files (new snapshots for a project that
# didn't exist in the data repo yet) are visible to the diff check. Without
# this, `git diff --quiet` reports a clean tree because it doesn't look at
# untracked paths, and we'd exit without publishing the new snapshot.
git add -A
if git diff --cached --quiet; then
    echo "No changes after publish; nothing to commit."
    exit 0
fi

case "${MODE}" in
    preview)
        COMMIT_MSG="Update preview for ${PROJECT_NAME} PR #${PR_NUMBER}"
        ;;
    history)
        COMMIT_MSG="Add history snapshot ${PROJECT_NAME} ${DATE}-${STEM}"
        ;;
    bulk-history)
        COMMIT_MSG="Backfill history snapshots for ${PROJECT_NAME}"
        ;;
    delete-preview)
        COMMIT_MSG="Drop preview for ${PROJECT_NAME} PR #${PR_NUMBER}"
        ;;
    set-latest)
        COMMIT_MSG="Refresh latest snapshot pointer for ${PROJECT_NAME}"
        ;;
esac

git commit -m "${COMMIT_MSG}"

# Retry-on-conflict push: instead of `git pull --rebase` (which can fail with
# a merge conflict on manifest.json under concurrent writers and abort the
# script via `set -e`), reset hard to remote HEAD and re-apply our changes.
# This works because:
#   - apply_change is idempotent on each mode (history/bulk-history skip
#     existing entries; preview overwrites; delete-preview is `rm -f`).
#   - manifest.json is rebuilt deterministically from the filesystem.
# Up to 5 attempts with linear backoff.
attempt=1
while (( attempt <= 5 )); do
    if git push origin "${DATA_REPO_BRANCH}"; then
        echo "Pushed on attempt ${attempt}."
        exit 0
    fi
    echo "Push rejected (attempt ${attempt}); resetting to remote and reapplying…"
    git fetch origin "${DATA_REPO_BRANCH}"
    git reset --hard "origin/${DATA_REPO_BRANCH}"
    apply_change
    if [[ -f scripts/build-manifest.mjs ]]; then
        node scripts/build-manifest.mjs
    fi
    git add -A
    if git diff --cached --quiet; then
        echo "After reapply, nothing to commit — concurrent writer already covered our changes."
        exit 0
    fi
    git commit -m "${COMMIT_MSG}"
    sleep $(( attempt * 3 ))
    (( attempt++ ))
done

echo "Push failed after 5 attempts; giving up." >&2
exit 1
