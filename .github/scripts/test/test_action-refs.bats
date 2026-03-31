#!/usr/bin/env bats

SCRIPTS_DIR="$BATS_TEST_DIRNAME/.."

setup() {
  # Ensure refs start at main
  bash "$SCRIPTS_DIR/bump-action-refs.sh" main >/dev/null
}

teardown() {
  # Always revert to main
  bash "$SCRIPTS_DIR/bump-action-refs.sh" main >/dev/null
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
