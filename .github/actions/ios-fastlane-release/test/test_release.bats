#!/usr/bin/env bats

load test_helper

SCRIPT="$BATS_TEST_DIRNAME/../release.sh"

setup() {
  MOCK_DIR="$(mktemp -d)"
  export PATH="$MOCK_DIR:$PATH"

  # Mock gem command (no-op)
  cat > "$MOCK_DIR/gem" <<'MOCK'
#!/bin/bash
exit 0
MOCK
  chmod +x "$MOCK_DIR/gem"

  # Mock bundle command — capture the full invocation
  BUNDLE_LOG="$(mktemp)"
  export BUNDLE_LOG
  cat > "$MOCK_DIR/bundle" <<MOCK
#!/bin/bash
if [ "\$1" = "exec" ]; then
  echo "\$@" >> "$BUNDLE_LOG"
fi
exit 0
MOCK
  chmod +x "$MOCK_DIR/bundle"
}

teardown() {
  rm -rf "$MOCK_DIR" "$BUNDLE_LOG"
}

@test "no overrides — runs fastlane release without args" {
  BUILD_NUMBER="" VERSION_NUMBER="" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^exec fastlane release$" "$BUNDLE_LOG"
}

@test "BUILD_NUMBER set — passes build_number arg" {
  BUILD_NUMBER="42" VERSION_NUMBER="" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^exec fastlane release build_number:42$" "$BUNDLE_LOG"
}

@test "VERSION_NUMBER set — passes version_number arg" {
  BUILD_NUMBER="" VERSION_NUMBER="1.2.0" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^exec fastlane release version_number:1.2.0$" "$BUNDLE_LOG"
}

@test "both set — passes both args" {
  BUILD_NUMBER="42" VERSION_NUMBER="1.2.0" run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  grep -q "^exec fastlane release build_number:42 version_number:1.2.0$" "$BUNDLE_LOG"
}
