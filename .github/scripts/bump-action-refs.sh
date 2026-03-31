#!/bin/bash
# Updates all internal futuredapp/.github action/workflow refs to a specified version tag.
# Run this before creating a new release tag so that consumer repos
# get pinned action refs matching the tag they reference.
#
# Usage: .github/scripts/bump-action-refs.sh <version>
# Example: .github/scripts/bump-action-refs.sh 2.3.0

set -euo pipefail

# Cross-platform sed in-place
sedi() {
    if sed --version >/dev/null 2>&1; then
        sed -i -E "$@"  # GNU (Linux)
    else
        sed -i '' -E "$@"  # BSD (macOS)
    fi
}

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Example: $0 2.3.0"
    exit 1
fi

NEW_VERSION="$1"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKFLOWS_DIR="$SCRIPT_DIR/../workflows"
ACTIONS_DIR="$SCRIPT_DIR/../actions"

updated=0

# Update workflow files
if [ -d "$WORKFLOWS_DIR" ]; then
    for file in "$WORKFLOWS_DIR"/*.yml; do
        if grep -q 'futuredapp/\.github/' "$file"; then
            sedi "s#(futuredapp/\.github/.+)@(main|[0-9]+\.[0-9]+\.[0-9]+)#\1@${NEW_VERSION}#g" "$file"
            echo "Updated: workflows/$(basename "$file")"
            updated=$((updated + 1))
        fi
    done
fi

# Update composite action files
if [ -d "$ACTIONS_DIR" ]; then
    find "$ACTIONS_DIR" -name 'action.yml' | while read -r file; do
        if grep -q 'futuredapp/\.github/' "$file"; then
            sedi "s#(futuredapp/\.github/.+)@(main|[0-9]+\.[0-9]+\.[0-9]+)#\1@${NEW_VERSION}#g" "$file"
            rel_path="${file#"$ACTIONS_DIR"/}"
            echo "Updated: actions/$rel_path"
            updated=$((updated + 1))
        fi
    done
fi

if [ "$updated" -eq 0 ]; then
    echo "No files with futuredapp/.github refs found."
else
    echo "Done. Updated $updated file(s) to @$NEW_VERSION."
fi
