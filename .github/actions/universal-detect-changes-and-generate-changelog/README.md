# Universal Detect Changes and Generate Changelog Action

This GitHub Action detects changes since the last built commit and generates a changelog. It uses modular bash scripts to provide maintainability, testability, and flexibility.

## Features

- ✅ **Nested Merge Detection**: Detects ALL merged branches including nested merges (e.g., B→A→develop reports both A and B)
- ✅ **Smart Filtering**: Automatically filters out reverse merges (main→feature) used for conflict resolution
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
| `use_git_lfs` | No | `false` | Whether to download Git-LFS files during checkout |
| `exclude_source_branches` | No | `"(main\|develop\|master)"` | Exclude merged commits of given branches. Regex pattern (ERE). Example: `"(release.*\|hotfix.*)"` |

## Outputs

| Output | Description |
|--------|-------------|
| `skip_build` | Indicates if the build should be skipped |
| `changelog` | The generated changelog formatted as a string |
| `merged_branches` | List of merged branch names |
| `cache_key` | Cache key to store latest built commit for this branch |

## Nested Merge Detection

The action detects **all merged branches** including nested merges where one feature branch merges into another before merging to main.

### How It Works

**Example:** Branch B merges into branch A, then A merges into develop
- **Output:** Both `feature-A` and `feature-B` are detected
- **Filtering:** Reverse merges (e.g., `develop→feature-A` for conflict resolution) are automatically excluded

### Implementation Details

- **Branch Names**: Uses `git log --merges` (without `--first-parent`) to see all merge commits
- **Changelog Messages**: Uses `git log --merges --first-parent` to follow only main branch history
- **Filtering**: Excludes source branches via `grep -v "Merge branch '(EXCLUDE_SOURCE_BRANCHES)' into"`

### Performance Considerations

Removing `--first-parent` for branch detection means git traverses more of the commit graph:
- **Impact**: Minimal for typical workflows (10-100 commits between builds)
- **Large histories**: May add 1-2 seconds for repos with 1000+ commits in the range
- **Recommendation**: Use `checkout_depth` to limit git history fetch depth if needed

The performance tradeoff is generally acceptable given the improved accuracy in branch detection.

## Scripts

### `cache-keys.sh`
Handles cache key calculation.

**Environment Variables:**
- `CACHE_KEY_PREFIX`: Custom cache key prefix
- `DEBUG`: Debug mode flag

**Outputs:**
- `cache_key_prefix`: Generated cache key prefix (format: `latest_builded_commit-` or `{prefix}-latest_builded_commit-`)

### `determine-range.sh`
Determines commit range and skip build logic.

**Environment Variables:**
- `DEBUG`: Debug mode flag
- `FALLBACK_LOOKBACK`: Fallback time window

**Outputs:**
- `build_should_skip`: Whether to skip the build
- `from_commit`: Starting commit for changelog
- `to_commit`: Ending commit for changelog

### `generate-changelog.sh`
Generates formatted changelog and branch names with nested merge detection.

**Environment Variables:**
- `FROM_COMMIT`: Starting commit
- `TO_COMMIT`: Ending commit
- `EXCLUDE_SOURCE_BRANCHES`: Regex pattern for excluding source branches (default: `(main|develop|master)`)
- `DEBUG`: Debug mode flag

**Outputs:**
- `changelog_string`: Formatted changelog (from main branch history only)
- `merged_branches`: List of all merged branches (includes nested merges)

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
bats test/test_merged-branches.bats
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
- ✅ **Nested merge detection** (B→A→develop, C→B→A→develop)
- ✅ **Reverse merge filtering** (conflict resolution exclusion)
- ✅ **Custom target branch patterns**
- ✅ Error handling and edge cases
- ✅ Debug output functionality
- ✅ Git command failure scenarios
- ✅ Empty input handling
- ✅ Special characters and edge cases
