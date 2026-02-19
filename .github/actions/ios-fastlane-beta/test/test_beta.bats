#!/usr/bin/env bats

load test_helper

SCRIPT="$BATS_TEST_DIRNAME/../beta.sh"

@test "no overrides — runs fastlane beta without args" {
  BUILD_NUMBER="" VERSION_NUMBER="" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^exec fastlane beta$" "$BUNDLE_LOG"
}

@test "BUILD_NUMBER set — passes build_number arg" {
  BUILD_NUMBER="42" VERSION_NUMBER="" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^exec fastlane beta build_number:42$" "$BUNDLE_LOG"
}

@test "VERSION_NUMBER set — passes version_number arg" {
  BUILD_NUMBER="" VERSION_NUMBER="1.2.0" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^exec fastlane beta version_number:1.2.0$" "$BUNDLE_LOG"
}

@test "both set — passes both args" {
  BUILD_NUMBER="42" VERSION_NUMBER="1.2.0" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^exec fastlane beta build_number:42 version_number:1.2.0$" "$BUNDLE_LOG"
}
