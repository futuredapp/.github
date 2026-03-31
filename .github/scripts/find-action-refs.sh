#!/bin/bash
# Finds all files containing futuredapp/.github refs in workflows and composite actions.
# Outputs one file path per line.
#
# Usage: .github/scripts/find-action-refs.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOWS_DIR="$SCRIPT_DIR/../workflows"
ACTIONS_DIR="$SCRIPT_DIR/../actions"

files=()

if [ -d "$WORKFLOWS_DIR" ]; then
    for file in "$WORKFLOWS_DIR"/*.yml; do
        [ -f "$file" ] && grep -lq 'futuredapp/\.github/' "$file" && files+=("$file")
    done
fi

if [ -d "$ACTIONS_DIR" ]; then
    while IFS= read -r file; do
        files+=("$file")
    done < <(find "$ACTIONS_DIR" -name 'action.yml' -exec grep -l 'futuredapp/\.github/' {} +)
fi

printf '%s\n' "${files[@]}"
