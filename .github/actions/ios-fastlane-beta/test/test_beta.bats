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

@test "empty issuer ID — unset so fastlane treats the key as individual" {
  APP_STORE_CONNECT_API_KEY_ISSUER_ID="" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q "^APP_STORE_CONNECT_API_KEY_ISSUER_ID=" "$ENV_LOG"
}

@test "whitespace-only issuer ID — unset" {
  APP_STORE_CONNECT_API_KEY_ISSUER_ID="  " run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  ! grep -q "^APP_STORE_CONNECT_API_KEY_ISSUER_ID=" "$ENV_LOG"
}

@test "issuer ID set — passed through to fastlane" {
  APP_STORE_CONNECT_API_KEY_ISSUER_ID="abc-123" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^APP_STORE_CONNECT_API_KEY_ISSUER_ID=abc-123$" "$ENV_LOG"
}
