#!/usr/bin/env bash
set -euo pipefail

# CodeCharta + DependaCharta analysis pipeline.
#
# Invoked by the universal-codecharta-snapshot composite action. Reads
# configuration from environment variables (set by action.yml from action
# inputs). Operates in two modes:
#
#   snapshot — analyze HEAD; produces `${OUT_DIR}/${PROJECT_NAME}.cc.json.gz`
#              plus `${OUT_DIR}/${PROJECT_NAME}.cg.json`.
#   history  — walk N recent first-parent merge commits; produces one
#              `${PROJECT_NAME}-<date>-<stem>.cc.json.gz` (plus optional
#              `.meta.json` sidecar) per merge into
#              `${OUT_DIR}/pull-requests/`.
#
# All paths emitted to $GITHUB_OUTPUT use absolute paths so consumers don't
# have to know REPO_ROOT.

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
PROJECT_NAME="${CODECHARTA_PROJECT_NAME:?CODECHARTA_PROJECT_NAME is required}"
OUT_DIR="${CODECHARTA_OUT_DIR:-build/codecharta}"
STACK="${CODECHARTA_STACK:-multi}"
ANALYSIS_IMAGE="${CODECHARTA_ANALYSIS_IMAGE:-codecharta/codecharta-analysis:latest}"
DEPENDACHARTA_IMAGE="${DEPENDACHARTA_IMAGE:-ghcr.io/futuredapp/dependacharta-swift:fork-v0.2.1}"
DEPENDACHARTA_RUNNER="${DEPENDACHARTA_RUNNER:-docker}"
PLATFORM="${CODECHARTA_PLATFORM-linux/amd64}"
HISTORY_LIMIT="${CODECHARTA_HISTORY_PULL_REQUEST_LIMIT:-}"

DOCKER_PLATFORM_ARGS=()
if [[ -n "${PLATFORM}" ]]; then
    DOCKER_PLATFORM_ARGS=(--platform "${PLATFORM}")
fi

# ── Stack profile resolution ─────────────────────────────────────────────────
# Stack maps to a default file-extension list (for ccsh `-fe=`) and a default
# tokei type list (for `--type`). Explicit overrides via CODECHARTA_FILE_
# EXTENSIONS / CODECHARTA_TOKEI_TYPES always win.

case "${STACK}" in
    swift)
        STACK_FE="swift"
        STACK_TOKEI="Swift,Objective-C"
        ;;
    kotlin)
        STACK_FE="kt"
        STACK_TOKEI="Kotlin,Java"
        ;;
    kmp)
        STACK_FE="kt,swift"
        STACK_TOKEI="Kotlin,Swift,Java,Objective-C"
        ;;
    ft-fullstack)
        STACK_FE="ts,tsx,js,jsx,mjs,cjs,vue"
        STACK_TOKEI="TypeScript,JavaScript,Vue"
        ;;
    multi)
        STACK_FE=""
        STACK_TOKEI=""
        ;;
    *)
        echo "Unknown CODECHARTA_STACK: '${STACK}'. Expected one of: swift, kotlin, kmp, ft-fullstack, multi." >&2
        exit 64
        ;;
esac

FILE_EXTENSIONS="${CODECHARTA_FILE_EXTENSIONS:-${STACK_FE}}"
TOKEI_TYPES="${CODECHARTA_TOKEI_TYPES:-${STACK_TOKEI}}"
EXTRA_EXCLUDES="${CODECHARTA_EXTRA_EXCLUDES:-}"

# Note: the ccsh `-fe=…` flag, tokei `--type` flag, and exclude lists are
# re-derived inside the Docker `bash -lc` heredocs below because the host
# environment doesn't transit naturally into the container. The env vars above
# are passed in via `-e CC_*=…`; the inner bash builds the array forms from them.

# ── Dependency metric descriptors ────────────────────────────────────────────

add_dependency_metric_descriptions() {
    local map_path="$1"

    if ! command -v node >/dev/null 2>&1; then
        echo "node is required to add dependency metric descriptions to ${map_path}" >&2
        exit 69
    fi

    node - "${map_path}" <<'NODE'
const fs = require("fs");
const zlib = require("zlib");

const mapPath = process.argv[2];
const isGzip = mapPath.endsWith(".gz");
const raw = fs.readFileSync(mapPath);
const json = JSON.parse(isGzip ? zlib.gunzipSync(raw) : raw);
json.data.attributeDescriptors ??= {};
json.data.attributeDescriptors.dependencies = {
  ...json.data.attributeDescriptors.dependencies,
  title: "Dependencies",
  description: "Number of incoming and outgoing dependency edges aggregated from the DependaCharta graph.",
  hintLowValue: "Fewer dependency edges",
  hintHighValue: "More dependency edges",
  direction: -1,
  analyzers: ["DependaCharta", "CodeCharta EdgeFilter"],
};

const output = JSON.stringify(json);
fs.writeFileSync(mapPath, isGzip ? zlib.gzipSync(output) : output);
NODE

    echo "Added dependency metric descriptions to ${map_path}"
}

# ── DependaCharta runner ─────────────────────────────────────────────────────

run_dependacharta() {
    local absolute_out_dir="$1"

    if [[ "${DEPENDACHARTA_RUNNER}" != "docker" ]]; then
        echo "DEPENDACHARTA_RUNNER must be 'docker' inside the action (got '${DEPENDACHARTA_RUNNER}')" >&2
        exit 64
    fi

    mkdir -p "${absolute_out_dir}"

    docker run --rm \
        -v "${REPO_ROOT}:/source:ro" \
        -v "${absolute_out_dir}:/output" \
        "${DEPENDACHARTA_IMAGE}" \
        -d /source \
        -o /output \
        -f "${PROJECT_NAME}" \
        -c \
        --logLevel info
}

# ── Pull-request metadata sidecars ───────────────────────────────────────────

pull_request_metadata() {
    local snapshot_dir="$1"

    if ! command -v gh >/dev/null 2>&1; then
        echo "gh CLI not found on PATH; skipping pull-request metadata generation."
        return 0
    fi

    local repo_slug
    if [[ -n "${GITHUB_REPOSITORY:-}" ]]; then
        repo_slug="${GITHUB_REPOSITORY}"
    elif ! repo_slug=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null); then
        echo "Could not determine GitHub repo slug; skipping pull-request metadata."
        return 0
    fi

    shopt -s nullglob
    local cc
    for cc in "${snapshot_dir}/${PROJECT_NAME}"-*-pr-*.cc.json.gz; do
        local base="${cc%.cc.json.gz}"
        local meta="${base}.meta.json"

        if [[ -f "${meta}" ]]; then
            continue
        fi

        local pr_number
        if [[ "${base}" =~ -pr-([0-9]+)$ ]]; then
            pr_number="${BASH_REMATCH[1]}"
        else
            continue
        fi

        if gh pr view "${pr_number}" --repo "${repo_slug}" \
            --json title,author,mergedAt,url > "${meta}" 2>/dev/null; then
            echo "Wrote ${meta}"
        else
            echo "Could not fetch metadata for PR #${pr_number}; skipping."
            rm -f "${meta}"
        fi
    done
}

# ── Snapshot pipeline (single snapshot at HEAD) ──────────────────────────────

snapshot() {
    local absolute_out_dir="${REPO_ROOT}/${OUT_DIR}"
    local final_map_path="${absolute_out_dir}/${PROJECT_NAME}.cc.json.gz"
    local graph_path="${absolute_out_dir}/${PROJECT_NAME}.cg.json"

    mkdir -p "${absolute_out_dir}/tmp"

    run_dependacharta "${absolute_out_dir}"

    # Run ccsh (unifiedparser, gitlogparser, tokei, merge) in a single Docker
    # invocation so intermediate files share an in-container working dir.
    docker run --rm \
        "${DOCKER_PLATFORM_ARGS[@]}" \
        --user "$(id -u):$(id -g)" \
        -e HOME="/tmp/codecharta-home" \
        -e CC_PROJECT_NAME="${PROJECT_NAME}" \
        -e CC_OUT_DIR="${OUT_DIR}" \
        -e CC_FILE_EXTENSIONS="${FILE_EXTENSIONS}" \
        -e CC_TOKEI_TYPES="${TOKEI_TYPES}" \
        -e CC_EXTRA_EXCLUDES="${EXTRA_EXCLUDES}" \
        -v "${REPO_ROOT}:/mnt/src" \
        -w /mnt/src \
        "${ANALYSIS_IMAGE}" \
        bash -lc '
            set -euo pipefail

            mkdir -p "${HOME}" "${CC_OUT_DIR}/tmp"
            git config --global --add safe.directory /mnt/src

            source_map="${CC_OUT_DIR}/tmp/${CC_PROJECT_NAME}-source"
            git_map="${CC_OUT_DIR}/tmp/${CC_PROJECT_NAME}-git"
            tokei_json="${CC_OUT_DIR}/tmp/${CC_PROJECT_NAME}-tokei.json"
            tokei_map="${CC_OUT_DIR}/tmp/${CC_PROJECT_NAME}-tokei"
            graph="${CC_OUT_DIR}/${CC_PROJECT_NAME}.cg.json"
            dependency_edges="${CC_OUT_DIR}/${CC_PROJECT_NAME}-dependencies.cc.json.gz"
            dependency_metrics="${CC_OUT_DIR}/${CC_PROJECT_NAME}-dependency-metrics.cc.json"
            final_map="${CC_OUT_DIR}/${CC_PROJECT_NAME}"

            # Build ccsh flag arrays from env. Empty values produce zero array
            # elements, leaving ccsh to use its built-in defaults.
            fe_args=()
            if [[ -n "${CC_FILE_EXTENSIONS}" ]]; then
                fe_args+=("-fe=${CC_FILE_EXTENSIONS}")
            fi
            exclude_args=()
            if [[ -n "${CC_EXTRA_EXCLUDES}" ]]; then
                IFS="," read -ra patterns <<< "${CC_EXTRA_EXCLUDES}"
                for p in "${patterns[@]}"; do
                    exclude_args+=("-e=${p}")
                done
            fi
            tokei_type_args=()
            if [[ -n "${CC_TOKEI_TYPES}" ]]; then
                tokei_type_args+=(--type "${CC_TOKEI_TYPES}")
            fi
            tokei_exclude_args=()
            if [[ -n "${CC_EXTRA_EXCLUDES}" ]]; then
                IFS="," read -ra patterns <<< "${CC_EXTRA_EXCLUDES}"
                for p in "${patterns[@]}"; do
                    tokei_exclude_args+=(--exclude "${p}")
                done
            fi

            # Source structure (+ tokei LOC + git churn) merged into one map.
            ccsh unifiedparser \
                "${fe_args[@]}" \
                "${exclude_args[@]}" \
                -o="${source_map}" \
                .

            tokei \
                --output json \
                "${tokei_type_args[@]}" \
                "${tokei_exclude_args[@]}" \
                . > "${tokei_json}"

            ccsh tokeiimporter "${tokei_json}" --root-name . -o "${tokei_map}"

            base_inputs=("${source_map}.cc.json.gz" "${tokei_map}.cc.json.gz")
            if ccsh gitlogparser repo-scan --repo-path /mnt/src --silent -o "${git_map}"; then
                base_inputs+=("${git_map}.cc.json.gz")
            else
                echo "CodeCharta git history parser failed; continuing without git metrics."
            fi

            # DependaCharta graph → CodeCharta dependency metrics → merged map.
            if [[ -f "${graph}" ]]; then
                ccsh dependachartaimport "${graph}" -o "${dependency_edges}"
                ccsh edgefilter "${dependency_edges}" -o "${dependency_metrics}"
                base_inputs+=("${dependency_metrics}")
            else
                echo "DependaCharta graph missing at ${graph}; continuing without dependency metrics."
            fi

            ccsh merge -o="${final_map}" "${base_inputs[@]}"
            ccsh check "${final_map}.cc.json.gz"
            echo "Created ${final_map}.cc.json.gz"
        '

    if [[ -f "${final_map_path}" ]]; then
        add_dependency_metric_descriptions "${final_map_path}" || true
    fi

    # Expose outputs to the composite action.
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "cc_path=${final_map_path}" >> "${GITHUB_OUTPUT}"
        if [[ -f "${graph_path}" ]]; then
            echo "cg_path=${graph_path}" >> "${GITHUB_OUTPUT}"
        else
            echo "cg_path=" >> "${GITHUB_OUTPUT}"
        fi
        echo "snapshots_dir=" >> "${GITHUB_OUTPUT}"
    fi
}

# ── History pipeline (N snapshots over recent first-parent merges) ───────────

history() {
    local limit="${HISTORY_LIMIT}"
    local absolute_out_dir="${REPO_ROOT}/${OUT_DIR}/pull-requests"

    if [[ -n "${limit}" ]] && (! [[ "${limit}" =~ ^[0-9]+$ ]] || (( limit < 1 ))); then
        echo "history: limit must be empty or a positive integer (got '${limit}')" >&2
        exit 64
    fi

    mkdir -p "${absolute_out_dir}"

    docker run --rm \
        "${DOCKER_PLATFORM_ARGS[@]}" \
        --user "$(id -u):$(id -g)" \
        -e HOME="/tmp/codecharta-home" \
        -e CC_PROJECT_NAME="${PROJECT_NAME}" \
        -e CC_OUT_DIR="${OUT_DIR}/pull-requests" \
        -e CC_FILE_EXTENSIONS="${FILE_EXTENSIONS}" \
        -e CC_EXTRA_EXCLUDES="${EXTRA_EXCLUDES}" \
        -e CC_PULL_REQUEST_LIMIT="${limit}" \
        -v "${REPO_ROOT}:/mnt/src" \
        -w /mnt/src \
        "${ANALYSIS_IMAGE}" \
        bash -lc '
            set -euo pipefail

            mkdir -p "${HOME}" "${CC_OUT_DIR}"
            git config --global --add safe.directory /mnt/src

            fe_args=()
            if [[ -n "${CC_FILE_EXTENSIONS}" ]]; then
                fe_args+=("-fe=${CC_FILE_EXTENSIONS}")
            fi
            exclude_args=()
            if [[ -n "${CC_EXTRA_EXCLUDES}" ]]; then
                IFS="," read -ra patterns <<< "${CC_EXTRA_EXCLUDES}"
                for p in "${patterns[@]}"; do
                    exclude_args+=("-e=${p}")
                done
            fi

            generated=0
            # Use ASCII unit separator (\x1f) as field delimiter rather than `|`
            # — pipe characters are legal in commit subjects and would otherwise
            # split a single record across multiple fields.
            sep=$'\x1f'
            log_args=(--first-parent --merges "--format=%H${sep}%cs${sep}%s")
            if [[ -n "${CC_PULL_REQUEST_LIMIT}" ]]; then
                log_args=(-n "${CC_PULL_REQUEST_LIMIT}" "${log_args[@]}")
            fi

            mapfile -t merge_commits < <(git log "${log_args[@]}" HEAD)

            if (( ${#merge_commits[@]} == 0 )); then
                echo "No first-parent merge commits found."
                exit 0
            fi

            for merge_commit in "${merge_commits[@]}"; do
                IFS="${sep}" read -r sha snapshot_date subject <<< "${merge_commit}"
                short_sha="${sha:0:7}"

                if [[ "${subject}" =~ [Pp]ull[[:space:]]+[Rr]equest[[:space:]]+\#([0-9]+) ]]; then
                    pull_request_id="pr-${BASH_REMATCH[1]}"
                else
                    pull_request_id="merge-${short_sha}"
                fi

                output_path="${CC_OUT_DIR}/${CC_PROJECT_NAME}-${snapshot_date}-${pull_request_id}"

                if [[ -f "${output_path}.cc.json.gz" ]]; then
                    echo "[${snapshot_date} ${pull_request_id}] snapshot already exists; skipping."
                    continue
                fi

                echo "[${snapshot_date} ${pull_request_id}] generating snapshot at ${short_sha}: ${subject}"

                ccsh unifiedparser \
                    "${fe_args[@]}" \
                    "${exclude_args[@]}" \
                    --commit="${sha}" \
                    -o="${output_path}" \
                    .

                # When --commit is set, ccsh prefixes the output basename with
                # the short SHA. Find that file and rename it back.
                produced=$(ls -1 "${CC_OUT_DIR}"/*."${CC_PROJECT_NAME}-${snapshot_date}-${pull_request_id}.cc.json.gz" 2>/dev/null | head -1 || true)
                if [[ -z "${produced}" ]]; then
                    echo "[${snapshot_date} ${pull_request_id}] parser did not produce expected output; skipping."
                    continue
                fi
                mv "${produced}" "${output_path}.cc.json.gz"

                ccsh check "${output_path}.cc.json.gz" >/dev/null
                generated=$((generated + 1))
            done

            echo ""
            echo "Generated ${generated} new pull-request snapshot(s) in ${CC_OUT_DIR}/"
        '

    pull_request_metadata "${absolute_out_dir}"

    # Expose outputs.
    if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
        echo "cc_path=" >> "${GITHUB_OUTPUT}"
        echo "cg_path=" >> "${GITHUB_OUTPUT}"
        echo "snapshots_dir=${absolute_out_dir}" >> "${GITHUB_OUTPUT}"
    fi
}

# ── Entrypoint ───────────────────────────────────────────────────────────────

case "${1:-snapshot}" in
    snapshot)
        snapshot
        ;;
    history)
        history
        ;;
    *)
        echo "Usage: codecharta.sh {snapshot|history}" >&2
        exit 64
        ;;
esac
