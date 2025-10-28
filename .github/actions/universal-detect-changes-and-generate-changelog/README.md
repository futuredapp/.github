# Universal Detect Changes and Generate Changelog Action

This GitHub Action detects changes since the last built commit and generates a changelog. It has been refactored into modular bash scripts for better maintainability and testability.

## Features

- ✅ **Modular Design**: Split into separate bash scripts for better maintainability
- ✅ **Customizable Cache Keys**: Support for custom cache key prefixes (format: `latest_builded_commit-` or `{prefix}-latest_builded_commit-`)
- ✅ **GitHub-Native**: Leverages GitHub's built-in branch handling (no manual sanitization)
- ✅ **Comprehensive Testing**: Unit tests for all bash scripts
- ✅ **Debug Support**: Detailed debug output when enabled

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `checkout_depth` | No | `100` | The depth of the git history to fetch |
| `debug` | No | `false` | Enable debug mode for detailed logging |
| `fallback_lookback` | No | `"24 hours"` | Time to look back for merge commits when no previous build commit is found |
| `cache_key_prefix` | No | - | Custom prefix for cache keys. If not provided, will use `latest_builded_commit-`. If provided, format will be `{prefix}-latest_builded_commit-` |

## Outputs

| Output | Description |
|--------|-------------|
| `skip_build` | Indicates if the build should be skipped |
| `changelog` | The generated changelog formatted as a string |
| `merged_branches` | List of merged branch names |
| `cache_key` | Cache key to store latest built commit for this branch |

## Scripts

### `cache-keys.sh`
Handles cache key calculation.

**Environment Variables:**
- `INPUT_CACHE_KEY_PREFIX`: Custom cache key prefix
- `INPUT_DEBUG`: Debug mode flag

**Outputs:**
- `cache_key_prefix`: Generated cache key prefix (format: `latest_builded_commit-` or `{prefix}-latest_builded_commit-`)

### `determine-range.sh`
Determines commit range and skip build logic.

**Environment Variables:**
- `INPUT_DEBUG`: Debug mode flag
- `INPUT_FALLBACK_LOOKBACK`: Fallback time window

**Outputs:**
- `build_should_skip`: Whether to skip the build
- `from_commit`: Starting commit for changelog
- `to_commit`: Ending commit for changelog

### `generate-changelog.sh`
Generates formatted changelog and branch names.

**Environment Variables:**
- `INPUT_FROM_COMMIT`: Starting commit
- `INPUT_TO_COMMIT`: Ending commit
- `INPUT_DEBUG`: Debug mode flag

**Outputs:**
- `changelog_string`: Formatted changelog
- `merged_branches`: List of merged branches

## Testing

The action includes comprehensive unit tests using BATS (Bash Automated Testing System) and automated CI testing.

### Running Tests

```bash
# Run all tests
./test/run_tests.sh

# Run specific test file
bats test/test_cache-keys.bats
bats test/test_determine-range.bats
bats test/test_generate-changelog.bats
```

### CI Testing

Tests run automatically on pull requests when relevant files change. The CI workflow includes:
- Unit tests for all bash scripts
- YAML syntax validation
- Concurrency cancellation (new commits cancel old tests)

### Test Coverage

- ✅ Cache key generation with custom prefixes
- ✅ Branch name detection and fallback logic
- ✅ Commit range determination logic
- ✅ Skip build decision making
- ✅ Changelog generation and formatting
- ✅ Error handling and edge cases
- ✅ Debug output functionality
- ✅ Git command failure scenarios
- ✅ Empty input handling
- ✅ Special characters and edge cases

## Usage Example

```yaml
- name: Detect changes and generate changelog
  uses: ./.github/actions/universal-detect-changes-and-generate-changelog
  with:
    cache_key_prefix: "my-custom-prefix"
    debug: true
    fallback_lookback: "48 hours"
```

## Migration from Previous Version

The refactored version maintains full backward compatibility. Key changes:

1. **Removed branch sanitization**: GitHub now handles this automatically
2. **Added cache key prefix input**: For better customization
3. **Modular scripts**: Better maintainability and testability
4. **Enhanced testing**: Comprehensive unit test coverage with CI automation

## Development

### Adding New Features

1. Implement the feature in the appropriate script
2. Add unit tests for the new functionality
3. Update this README if needed
4. Test thoroughly with different scenarios

### Debugging

Enable debug mode to see detailed logging:

```yaml
with:
  debug: true
```

This will show:
- Branch and workflow name detection
- Cache key generation details
- Commit range determination logic
- Changelog generation process
