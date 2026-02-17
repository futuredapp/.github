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
