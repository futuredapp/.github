#!/usr/bin/env bats

load test_helper

SCRIPT="$BATS_TEST_DIRNAME/../parse-version-tag.sh"

@test "parses simple version tag 1.0.0" {
  VERSION_TAG="1.0.0" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^version_number=1.0.0$" "$GITHUB_OUTPUT"
  ! grep -q "^build_number=" "$GITHUB_OUTPUT"
}

@test "parses version tag with suffix 1.2.3-42" {
  VERSION_TAG="1.2.3-42" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^version_number=1.2.3$" "$GITHUB_OUTPUT"
  ! grep -q "^build_number=" "$GITHUB_OUTPUT"
}

@test "parses large version numbers 10.20.30-999" {
  VERSION_TAG="10.20.30-999" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^version_number=10.20.30$" "$GITHUB_OUTPUT"
  ! grep -q "^build_number=" "$GITHUB_OUTPUT"
}

@test "parses version tag with zero suffix 1.0.0-0" {
  VERSION_TAG="1.0.0-0" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^version_number=1.0.0$" "$GITHUB_OUTPUT"
  ! grep -q "^build_number=" "$GITHUB_OUTPUT"
}

@test "parses tag with pre-release suffix 1.0.0-beta.1" {
  VERSION_TAG="1.0.0-beta.1" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^version_number=1.0.0$" "$GITHUB_OUTPUT"
  ! grep -q "^build_number=" "$GITHUB_OUTPUT"
}

@test "parses tag with trailing dash 1.2.3-" {
  VERSION_TAG="1.2.3-" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^version_number=1.2.3$" "$GITHUB_OUTPUT"
  ! grep -q "^build_number=" "$GITHUB_OUTPUT"
}

@test "parses tag with text suffix 2.0.0-rc1" {
  VERSION_TAG="2.0.0-rc1" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^version_number=2.0.0$" "$GITHUB_OUTPUT"
  ! grep -q "^build_number=" "$GITHUB_OUTPUT"
}

@test "rejects v-prefixed tag v1.0.0" {
  VERSION_TAG="v1.0.0" run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "rejects incomplete version 1.0" {
  VERSION_TAG="1.0" run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}

@test "rejects empty tag" {
  VERSION_TAG="" run bash "$SCRIPT"
  [ "$status" -eq 1 ]
}
