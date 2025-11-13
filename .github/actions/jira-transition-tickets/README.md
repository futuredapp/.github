# JIRA Transition Tickets

A GitHub Action that automatically transitions JIRA tickets to a specified status based on merged branch names.

## Overview

This action helps automate JIRA ticket workflows by:
- Extracting JIRA ticket keys from branch names (e.g., `feature/ABC-123-add-feature`)
- Transitioning matched tickets to a target status (e.g., "Done", "In QA", "Ready for Testing")

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

### `target_status` (required)

The name of the JIRA status to transition tickets to. This must match the exact status name in your JIRA workflow.

**Examples:** `"Done"`, `"In QA"`, `"Ready for Testing"`, `"Closed"`

### `merged_branches` (required)

A comma-separated string of branch names from which to extract JIRA ticket keys.

The action extracts keys matching the pattern `[A-Z]+-[0-9]+` from each branch name.

**Example:** `"feature/ABC-123-login,bugfix/XYZ-456-fix-crash"`

## How It Works

1. **Extract JIRA Keys:** Parses branch names to extract ticket keys (e.g., `ABC-123`)
2. **Build JQL Query:** Creates a JQL query using extracted keys: `issueKey in (ABC-123, XYZ-456)`
3. **Search Issues:** Uses JIRA REST API to find matching issues
4. **Transition Issues:** Transitions each found issue to the target status

## Usage Examples

### Example 1: Transition tickets from merged branches

```yaml
- name: Transition JIRA tickets to Done
  uses: ./.github/actions/jira-transition-tickets
  with:
    jira_context: ${{ secrets.JIRA_CONTEXT }}
    target_status: "Done"
    merged_branches: "feature/PROJ-123-new-feature,bugfix/PROJ-456-bug-fix"
```

### Example 2: Transition tickets from dynamic branch list

```yaml
- name: Transition tickets
  uses: ./.github/actions/jira-transition-tickets
  with:
    jira_context: ${{ secrets.JIRA_CONTEXT }}
    target_status: "Ready for Testing"
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
        uses: ./.github/actions/jira-transition-tickets
        with:
          jira_context: ${{ secrets.JIRA_CONTEXT }}
          target_status: "In QA"
          merged_branches: ${{ github.head_ref }}
```
