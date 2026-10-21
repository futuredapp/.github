#!/usr/bin/env bats

REPO_GITHUB_DIR="$BATS_TEST_DIRNAME/../.."

setup() {
  # The scripts rewrite files in place: run them on a copy so the repository is never touched.
  WORK_DIR=$(mktemp -d)
  mkdir -p "$WORK_DIR/.github"
  cp -R "$REPO_GITHUB_DIR/scripts" "$REPO_GITHUB_DIR/workflows" "$REPO_GITHUB_DIR/actions" "$WORK_DIR/.github/"
  SCRIPTS_DIR="$WORK_DIR/.github/scripts"
  # Ensure refs start at main
  bash "$SCRIPTS_DIR/bump-action-refs.sh" main >/dev/null
}

teardown() {
  rm -rf "$WORK_DIR"
}

@test "find-action-refs returns files" {
  run bash "$SCRIPTS_DIR/find-action-refs.sh"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -gt 0 ]
}

@test "validate passes when refs match" {
  bash "$SCRIPTS_DIR/bump-action-refs.sh" 8.8.8 >/dev/null
  run bash "$SCRIPTS_DIR/validate-action-refs.sh" 8.8.8
  [ "$status" -eq 0 ]
}

@test "validate fails when refs don't match" {
  bash "$SCRIPTS_DIR/bump-action-refs.sh" 8.8.8 >/dev/null
  run bash "$SCRIPTS_DIR/validate-action-refs.sh" 9.9.9
  [ "$status" -eq 1 ]
}

@test "bump updates all refs to new version" {
  bash "$SCRIPTS_DIR/bump-action-refs.sh" 1.2.3 >/dev/null
  run bash "$SCRIPTS_DIR/validate-action-refs.sh" 1.2.3
  [ "$status" -eq 0 ]
}

@test "validate fails for old version after re-bump" {
  bash "$SCRIPTS_DIR/bump-action-refs.sh" 1.0.0 >/dev/null
  bash "$SCRIPTS_DIR/bump-action-refs.sh" 2.0.0 >/dev/null
  run bash "$SCRIPTS_DIR/validate-action-refs.sh" 1.0.0
  [ "$status" -eq 1 ]
}

@test "validate passes after revert to main" {
  bash "$SCRIPTS_DIR/bump-action-refs.sh" 8.8.8 >/dev/null
  bash "$SCRIPTS_DIR/bump-action-refs.sh" main >/dev/null
  run bash "$SCRIPTS_DIR/validate-action-refs.sh" main
  [ "$status" -eq 0 ]
}
