setup() {
  GITHUB_OUTPUT="$(mktemp)"
  export GITHUB_OUTPUT
}

teardown() {
  rm -f "$GITHUB_OUTPUT"
}
