# JIRA Transition Tickets

A GitHub Action that automatically transitions JIRA tickets to a specified status based on merged branch names.

## Overview

This action helps automate JIRA ticket workflows by:
- Extracting JIRA ticket keys from branch names (e.g., `feature/ABC-123-add-feature`)
- Transitioning matched tickets to a target status (e.g., "Done", "In QA", "Ready for Testing")

This action was designed to work with `merged_branches` output of [universal-detect-changes-and-generate-changelog](../universal-detect-changes-and-generate-changelog) action.

## Inputs

### `jira_context` (required)

A base64-encoded JSON string containing JIRA authentication credentials and configuration.

**Structure:**
```json
{
  "cloud_id": "your-cloud-id",
  "user_email": "your-bot@serviceaccount.atlassian.com",
  "api_token": "YourJiraApiToken"
}
```

**How to obtain Cloud ID:**

Navigate to [https://<cloudname>.atlassian.net/_edge/tenant_info](https://<cloudname>.atlassian.net/_edge/tenant_info)

**How to encode:**
```bash
echo -n '{"cloud_id":"your-cloud-id","user_email":"bot@example.com","api_token":"token"}' | base64
```

**GitHub Secrets:**
Store the base64-encoded string in a GitHub secret (e.g., `JIRA_CONTEXT`) for secure usage.

### `transition` (required)

The name of the JIRA transition to execute. This must match the exact transition name in your JIRA workflow.

**Examples:** `"Done"`, `"In QA"`, `"Ready for Testing"`, `"Closed"`

### `merged_branches` (required)

A comma-separated string of branch names from which to extract JIRA ticket keys.

The action extracts keys matching the pattern `[A-Z]+-[0-9]+` from each branch name.

**Example:** `"feature/ABC-123-login,bugfix/XYZ-456-fix-crash"`

## How It Works

1. **Extract JIRA Keys:** Parses branch names to extract ticket keys (e.g., `ABC-123`)
2. **Get Available Transitions:** For each issue key, fetches available transitions from JIRA API
3. **Find Target Transition:** Matches the target status name to find the corresponding transition ID
4. **Perform Transition:** Executes the transition for each issue to move it to the target status

## Usage Examples

### Example 1: Transition tickets from merged branches

```yaml
- name: Transition JIRA tickets
  uses: futuredapp/.github/.github/actions/jira-transition-tickets@main
  with:
    jira_context: ${{ secrets.JIRA_CONTEXT }}
    transition: "Ready for Testing"
    merged_branches: "feature/PROJ-123-new-feature,bugfix/PROJ-456-bug-fix"
```

### Example 2: Transition tickets from dynamic branch list

```yaml
- name: Transition tickets
  uses: futuredapp/.github/.github/actions/jira-transition-tickets@main
  with:
    jira_context: ${{ secrets.JIRA_CONTEXT }}
    transition: "Ready for Testing"
    merged_branches: ${{ steps.get_branches.outputs.branches }}
```

### Example 3: In a reusable workflow

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Build app
        run: ./build.sh

      - name: Transition JIRA tickets on success
        if: success()
        uses: futuredapp/.github/.github/actions/jira-transition-tickets@main
        with:
          jira_context: ${{ secrets.JIRA_CONTEXT }}
          transition: "Ready for Testing"
          merged_branches: ${{ github.head_ref }}
```
