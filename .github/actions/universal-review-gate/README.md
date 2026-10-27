# Review gate

Sets a commit status (default context `review-gate`) on the current PR head. Make it a required status check in the branch ruleset to replace a mandatory approval. It is green when one of these holds:

1. **The AI review bot reviewed exactly this commit and found low risk.** The bot's comment (written by `github-actions[bot]`, first line exactly `<!-- ai-pr-review sha=<40-character commit> risk=<low|high> -->`) must name the head commit. Comments from anyone else are ignored, and every push needs a new review.
2. **High risk, or the `needs-human` label, plus an approval of this commit.** The approval must come from someone other than the author whose repository permission is write, maintain or admin, as their latest decisive review, on the head commit. Removing the label does not lower a high-risk result.
3. **An approval of the head commit without any AI review.** This is the escape hatch for an AI outage and for bot-authored PRs.
4. **The PR targets a branch outside `review_base_branches`** (default `["develop"]`), e.g. a release PR into `main`. A commit status belongs to the commit, so when the same head commit also has an open PR into a reviewed branch (a hotfix into `main` and `develop`), the gate sets nothing here and leaves the status to that PR.

Otherwise it is `pending`, with a description saying what is missing.

It runs from [`universal-cloud-ai-pr-review`](../../workflows/universal-cloud-ai-pr-review.yml) on PR events (including `edited`, so a retargeted PR is re-evaluated) and review events, and at the end of every AI review run. The AI review run is needed because a comment created with `GITHUB_TOKEN` does not trigger other workflows. Both jobs use the concurrency group `review-gate-<repository>-<PR>`, so evaluations of one PR never overlap.

## Usage

```yaml
- uses: futuredapp/.github/.github/actions/universal-review-gate@main
  with:
    github_token: ${{ github.token }}
    pr_number: ${{ github.event.pull_request.number }}
```

The job needs `statuses: write`, `pull-requests: read` and `issues: read`.

A commit status can be set by anyone with write access to the repository, so the gate protects against mistakes, not against a colleague who bypasses it on purpose.
