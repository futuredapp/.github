#!/usr/bin/env bats

load 'test_helper'

@test "cache-keys: uses custom cache key prefix when provided" {
  export INPUT_CACHE_KEY_PREFIX="custom-prefix"
  export GITHUB_SHA="abc123"
  export INPUT_DEBUG="false"
  
  run ../cache-keys.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^cache_key_prefix=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "custom-prefix-latest_builded_commit-" ]
}

@test "cache-keys: generates default cache key prefix when not provided" {
  export INPUT_CACHE_KEY_PREFIX=""
  export GITHUB_SHA="def456"
  export INPUT_DEBUG="false"
  
  run ../cache-keys.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^cache_key_prefix=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "latest_builded_commit-" ]
}


@test "cache-keys: handles empty cache key prefix" {
  export INPUT_CACHE_KEY_PREFIX=""
  export GITHUB_SHA="empty123"
  export INPUT_DEBUG="false"
  
  run ../cache-keys.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^cache_key_prefix=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "latest_builded_commit-" ]
}

@test "cache-keys: handles whitespace-only cache key prefix" {
  export INPUT_CACHE_KEY_PREFIX="   "
  export GITHUB_SHA="whitespace123"
  export INPUT_DEBUG="false"
  
  run ../cache-keys.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^cache_key_prefix=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "   -latest_builded_commit-" ]
}

@test "cache-keys: handles special characters in cache key prefix" {
  export INPUT_CACHE_KEY_PREFIX="my-app@v1.0"
  export GITHUB_SHA="special123"
  export INPUT_DEBUG="false"
  
  run ../cache-keys.sh
  
  [ "$status" -eq 0 ]
  [ "$(grep '^cache_key_prefix=' "$GITHUB_OUTPUT" | cut -d= -f2)" = "my-app@v1.0-latest_builded_commit-" ]
}

@test "cache-keys: debug output when enabled" {
  export INPUT_CACHE_KEY_PREFIX="debug-prefix"
  export GITHUB_SHA="mno345"
  export INPUT_DEBUG="true"
  
  run ../cache-keys.sh
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "\[DEBUG\] INPUT_CACHE_KEY_PREFIX='debug-prefix'"
  echo "$output" | grep -q "\[DEBUG\] CACHE_KEY_PREFIX='debug-prefix-latest_builded_commit-'"
  echo "$output" | grep -q "\[DEBUG\] CALCULATED_CACHE_KEY='debug-prefix-latest_builded_commit-mno345'"
}
