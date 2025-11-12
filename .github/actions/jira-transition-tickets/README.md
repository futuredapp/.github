# JIRA Transition Tickets

A GitHub Action that automatically transitions JIRA tickets to a specified status based on merged branch names or JIRA components.

## Overview

This action helps automate JIRA ticket workflows by:
- Extracting JIRA ticket keys from branch names (e.g., `feature/ABC-123-add-feature`)
- Finding tickets by JIRA components
- Transitioning matched tickets to a target status (e.g., "Done", "In QA", "Ready for Testing")

## Inputs

### `jira_context` (required)

A base64-encoded JSON string containing JIRA authentication credentials and configuration.

**Structure:**
```json
{
  "base_url": "https://your-domain.atlassian.net",
  "user_email": "your-bot@serviceaccount.atlassian.com",
  "api_key": "YourJiraApiToken"
}
```

**How to encode:**
```bash
echo -n '{"base_url":"https://your-domain.atlassian.net","user_email":"bot@example.com","api_key":"token"}' | base64
```

**GitHub Secrets:**
Store the base64-encoded string in a GitHub secret (e.g., `JIRA_CONTEXT`) for secure usage.

### `target_status` (required)

The name of the JIRA status to transition tickets to. This must match the exact status name in your JIRA workflow.

**Examples:** `"Done"`, `"In QA"`, `"Ready for Testing"`, `"Closed"`

### `merged_branches` (optional)

A comma-separated string of branch names from which to extract JIRA ticket keys.

The action extracts keys matching the pattern `[A-Z]+-[0-9]+` from each branch name.

**Example:** `"feature/ABC-123-login,bugfix/XYZ-456-fix-crash"`

### `components` (optional)

A comma-separated string of JIRA component names. All tickets belonging to these components will be transitioned.

**Example:** `"Android,iOS,Backend"`

**Note:** At least one of `merged_branches` or `components` must be provided.

## How It Works

1. **Extract JIRA Keys:** Parses branch names to extract ticket keys (e.g., `ABC-123`)
2. **Build JQL Query:** Creates a JQL query using extracted keys and/or components
3. **Search Issues:** Uses JIRA REST API to find matching issues
4. **Transition Issues:** Transitions each found issue to the target status

**JQL Query Logic:**
- If both `merged_branches` and `components` are provided: `issueKey in (ABC-123, XYZ-456) OR component in (Android, iOS)`
- If only branches: `issueKey in (ABC-123, XYZ-456)`
- If only components: `component in (Android, iOS)`

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

### Example 2: Transition all tickets in specific components

```yaml
- name: Move Android tickets to In QA
  uses: ./.github/actions/jira-transition-tickets
  with:
    jira_context: ${{ secrets.JIRA_CONTEXT }}
    target_status: "In QA"
    components: "Android,Mobile"
```

### Example 3: Combined branches and components

```yaml
- name: Transition tickets
  uses: ./.github/actions/jira-transition-tickets
  with:
    jira_context: ${{ secrets.JIRA_CONTEXT }}
    target_status: "Ready for Testing"
    merged_branches: ${{ steps.get_branches.outputs.branches }}
    components: "Backend"
```

### Example 4: In a reusable workflow

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
