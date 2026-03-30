#!/usr/bin/env python3
"""Generate changelog by diffing workflow/action YAML API surfaces between tags.

Usage:
    python scripts/generate-changelog.py

Outputs docs/changelog.md with structured entries for each version tag,
grouped by: breaking changes, new/removed workflows & actions, input changes,
and internal changes.
"""

from __future__ import annotations

import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

import yaml

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT_DIR = SCRIPT_DIR.parent  # .github/ (inner) — docs live here
REPO_ROOT = ROOT_DIR.parent   # repo root — git commands run here

WORKFLOW_PREFIX = ".github/workflows/"
ACTION_PREFIX = ".github/actions/"

# Author name normalization — maps git author names to canonical display names.
# Add entries when the same person appears under multiple names/emails.
AUTHOR_ALIASES: dict[str, str] = {
    "ssestak": "Šimon Šesták",
    "matejsemancik": "Matej Semančík",
    "jan.mikulik": "Honza Mikulík",
    "xmadera": "Jan Maděra",
    "prochazkafilip": "Filip Procházka",
    "Ondrej Kalman": "Ondřej Kalman",
    "Matěj Kašpar Jirásek": "Matěj Kašpar Jirásek",  # normalize invisible char
    "Michal Martinů": "Michal Martinů",  # normalize invisible char
}

# Authors to exclude from contributor lists (bots).
AUTHOR_EXCLUDE: set[str] = {"github-actions[bot]"}


# ---------------------------------------------------------------------------
# Git helpers
# ---------------------------------------------------------------------------


def _git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        capture_output=True,
        text=True,
        cwd=REPO_ROOT,
    )
    if result.returncode != 0:
        return ""
    return result.stdout.strip()


def get_sorted_tags() -> list[str]:
    """Return version tags sorted by semver (ascending)."""
    raw = _git("tag", "--sort=v:refname")
    if not raw:
        return []
    return raw.splitlines()


def get_tag_date(tag: str) -> str:
    """Return the tag date as YYYY-MM-DD."""
    return _git("log", "-1", "--format=%ai", tag).split(" ")[0]


def list_files_at_tag(tag: str, prefix: str, suffix: str = "") -> list[str]:
    """List files under *prefix* at *tag*, optionally filtered by *suffix*."""
    raw = _git("ls-tree", "-r", "--name-only", tag, prefix)
    if not raw:
        return []
    paths = raw.splitlines()
    if suffix:
        paths = [p for p in paths if p.endswith(suffix)]
    return paths


def read_file_at_tag(tag: str, path: str) -> str:
    """Return file content at *tag*, or empty string if missing."""
    return _git("show", f"{tag}:{path}")


def _normalize_key(name: str) -> str:
    """Produce an ASCII-ish lowercase key for dedup (strip diacritics)."""
    import unicodedata
    nfkd = unicodedata.normalize("NFKD", name)
    return "".join(c for c in nfkd if not unicodedata.combining(c)).lower().strip()


def get_contributors(old_tag: str | None, new_tag: str) -> list[str]:
    """Return deduplicated, normalized author names between two tags."""
    if old_tag:
        raw = _git("log", "--format=%aN", f"{old_tag}..{new_tag}")
    else:
        raw = _git("log", "--format=%aN", new_tag)
    if not raw:
        return []

    seen: dict[str, str] = {}
    for name in raw.splitlines():
        if name in AUTHOR_EXCLUDE:
            continue
        canonical = AUTHOR_ALIASES.get(name, name)
        key = _normalize_key(canonical)
        # Keep the version with diacritics (longer NFKD form)
        if key not in seen or len(canonical) > len(seen[key]):
            seen[key] = canonical
    return sorted(seen.values())


def get_merge_pr_summaries(old_tag: str, new_tag: str) -> dict[str, list[str]]:
    """Return {file_path: [summary, ...]} for merge commits touching each file.

    Uses first-parent merge commit subjects (typically PR titles).
    """
    raw = _git(
        "log", "--first-parent", "--merges", "--format=%H %s",
        f"{old_tag}..{new_tag}",
    )
    if not raw:
        return {}

    result: dict[str, list[str]] = {}
    for line in raw.splitlines():
        parts = line.split(" ", 1)
        if len(parts) < 2:
            continue
        sha, subject = parts
        files_raw = _git("diff-tree", "--no-commit-id", "-r", "--name-only", sha)
        for fpath in files_raw.splitlines():
            result.setdefault(fpath, []).append(subject)
    return result


# ---------------------------------------------------------------------------
# YAML API parsing
# ---------------------------------------------------------------------------


@dataclass
class InputInfo:
    name: str
    description: str = ""
    type: str = "string"
    required: bool = False
    default: str | None = None


@dataclass
class SecretInfo:
    name: str
    description: str = ""
    required: bool = False


@dataclass
class OutputInfo:
    name: str
    description: str = ""


@dataclass
class APISpec:
    """Public API surface of a workflow or action."""
    name: str
    inputs: dict[str, InputInfo] = field(default_factory=dict)
    secrets: dict[str, SecretInfo] = field(default_factory=dict)
    outputs: dict[str, OutputInfo] = field(default_factory=dict)


def parse_workflow_api(yaml_text: str) -> APISpec | None:
    """Extract the public API surface from a workflow YAML string."""
    try:
        data = yaml.safe_load(yaml_text)
    except yaml.YAMLError:
        return None
    if not data or not isinstance(data, dict):
        return None

    name = data.get("name", "")
    on_block = data.get("on") or data.get(True) or {}
    wf_call = {}
    if isinstance(on_block, dict):
        wf_call = on_block.get("workflow_call", {}) or {}

    inputs = {}
    for k, v in (wf_call.get("inputs") or {}).items():
        v = v or {}
        default = v.get("default")
        inputs[k] = InputInfo(
            name=k,
            description=v.get("description", ""),
            type=v.get("type", "string"),
            required=v.get("required", False),
            default=str(default) if default is not None else None,
        )

    secrets = {}
    for k, v in (wf_call.get("secrets") or {}).items():
        v = v or {}
        secrets[k] = SecretInfo(
            name=k,
            description=v.get("description", ""),
            required=v.get("required", False),
        )

    outputs = {}
    for k, v in (wf_call.get("outputs") or {}).items():
        v = v or {}
        outputs[k] = OutputInfo(name=k, description=v.get("description", ""))

    return APISpec(name=name, inputs=inputs, secrets=secrets, outputs=outputs)


def parse_action_api(yaml_text: str) -> APISpec | None:
    """Extract the public API surface from an action YAML string."""
    try:
        data = yaml.safe_load(yaml_text)
    except yaml.YAMLError:
        return None
    if not data or not isinstance(data, dict):
        return None

    name = data.get("name", "")

    inputs = {}
    for k, v in (data.get("inputs") or {}).items():
        v = v or {}
        default = v.get("default")
        inputs[k] = InputInfo(
            name=k,
            description=v.get("description", ""),
            type=v.get("type", "string"),
            required=v.get("required", False),
            default=str(default) if default is not None else None,
        )

    outputs = {}
    for k, v in (data.get("outputs") or {}).items():
        v = v or {}
        outputs[k] = OutputInfo(name=k, description=v.get("description", ""))

    return APISpec(name=name, inputs=inputs, outputs=outputs)


# ---------------------------------------------------------------------------
# Diff engine
# ---------------------------------------------------------------------------


@dataclass
class InputChange:
    name: str
    change: str  # "added", "removed", "modified"
    details: str = ""


@dataclass
class SecretChange:
    name: str
    change: str  # "added", "removed"
    details: str = ""


@dataclass
class OutputChange:
    name: str
    change: str  # "added", "removed"
    details: str = ""


@dataclass
class FileDiff:
    """Changes to a single workflow or action file."""
    key: str  # workflow/action identifier (e.g. "ios-selfhosted-test")
    kind: str  # "workflow" or "action"
    status: str  # "added", "removed", "changed", "internal"
    name: str = ""
    input_changes: list[InputChange] = field(default_factory=list)
    secret_changes: list[SecretChange] = field(default_factory=list)
    output_changes: list[OutputChange] = field(default_factory=list)
    pr_summaries: list[str] = field(default_factory=list)

    @property
    def has_api_changes(self) -> bool:
        return bool(self.input_changes or self.secret_changes or self.output_changes)

    @property
    def has_breaking_changes(self) -> bool:
        return any(
            c.change == "removed"
            for c in self.input_changes + self.secret_changes + self.output_changes
        )


def _diff_inputs(
    old: dict[str, InputInfo], new: dict[str, InputInfo]
) -> list[InputChange]:
    changes = []
    for name in sorted(set(old) | set(new)):
        if name not in old:
            info = new[name]
            detail = f"type: `{info.type}`"
            if info.default is not None:
                detail += f", default: `{info.default}`"
            if info.required:
                detail += ", required"
            changes.append(InputChange(name, "added", detail))
        elif name not in new:
            changes.append(InputChange(name, "removed"))
        else:
            diffs = []
            o, n = old[name], new[name]
            if o.type != n.type:
                diffs.append(f"type: `{o.type}` -> `{n.type}`")
            if o.required != n.required:
                diffs.append(f"required: `{o.required}` -> `{n.required}`")
            if o.default != n.default:
                old_d = f"`{o.default}`" if o.default is not None else "_none_"
                new_d = f"`{n.default}`" if n.default is not None else "_none_"
                diffs.append(f"default: {old_d} -> {new_d}")
            if o.description != n.description and not diffs:
                diffs.append("description updated")
            if diffs:
                changes.append(InputChange(name, "modified", ", ".join(diffs)))
    return changes


def _diff_secrets(
    old: dict[str, SecretInfo], new: dict[str, SecretInfo]
) -> list[SecretChange]:
    changes = []
    for name in sorted(set(old) | set(new)):
        if name not in old:
            changes.append(SecretChange(name, "added"))
        elif name not in new:
            changes.append(SecretChange(name, "removed"))
        else:
            if old[name].required != new[name].required:
                changes.append(SecretChange(
                    name, "modified",
                    f"required: `{old[name].required}` -> `{new[name].required}`",
                ))
    return changes


def _diff_outputs(
    old: dict[str, OutputInfo], new: dict[str, OutputInfo]
) -> list[OutputChange]:
    changes = []
    for name in sorted(set(old) | set(new)):
        if name not in old:
            changes.append(OutputChange(name, "added"))
        elif name not in new:
            changes.append(OutputChange(name, "removed"))
    return changes


def diff_tags(old_tag: str, new_tag: str) -> list[FileDiff]:
    """Compute all workflow/action API diffs between two tags."""
    diffs: list[FileDiff] = []
    pr_summaries = get_merge_pr_summaries(old_tag, new_tag)

    # --- Workflows ---
    old_wfs = {
        Path(p).stem: p
        for p in list_files_at_tag(old_tag, WORKFLOW_PREFIX, ".yml")
    }
    new_wfs = {
        Path(p).stem: p
        for p in list_files_at_tag(new_tag, WORKFLOW_PREFIX, ".yml")
    }

    for key in sorted(set(old_wfs) | set(new_wfs)):
        if key in ("deploy-docs",):
            continue

        if key not in old_wfs:
            path = new_wfs[key]
            api = parse_workflow_api(read_file_at_tag(new_tag, path))
            diffs.append(FileDiff(
                key=key, kind="workflow", status="added",
                name=api.name if api else key,
            ))
        elif key not in new_wfs:
            api = parse_workflow_api(read_file_at_tag(old_tag, old_wfs[key]))
            diffs.append(FileDiff(
                key=key, kind="workflow", status="removed",
                name=api.name if api else key,
            ))
        else:
            old_text = read_file_at_tag(old_tag, old_wfs[key])
            new_text = read_file_at_tag(new_tag, new_wfs[key])
            if old_text == new_text:
                continue
            old_api = parse_workflow_api(old_text)
            new_api = parse_workflow_api(new_text)
            if not old_api or not new_api:
                continue

            fd = FileDiff(
                key=key, kind="workflow", status="changed",
                name=new_api.name,
                input_changes=_diff_inputs(old_api.inputs, new_api.inputs),
                secret_changes=_diff_secrets(old_api.secrets, new_api.secrets),
                output_changes=_diff_outputs(old_api.outputs, new_api.outputs),
                pr_summaries=pr_summaries.get(new_wfs[key], []),
            )
            fd.status = "changed" if fd.has_api_changes else "internal"
            diffs.append(fd)

    # --- Actions ---
    old_acts = {
        Path(p).parent.name: p
        for p in list_files_at_tag(old_tag, ACTION_PREFIX, "action.yml")
    }
    new_acts = {
        Path(p).parent.name: p
        for p in list_files_at_tag(new_tag, ACTION_PREFIX, "action.yml")
    }

    for key in sorted(set(old_acts) | set(new_acts)):
        if key not in old_acts:
            path = new_acts[key]
            api = parse_action_api(read_file_at_tag(new_tag, path))
            diffs.append(FileDiff(
                key=key, kind="action", status="added",
                name=api.name if api else key,
            ))
        elif key not in new_acts:
            api = parse_action_api(read_file_at_tag(old_tag, old_acts[key]))
            diffs.append(FileDiff(
                key=key, kind="action", status="removed",
                name=api.name if api else key,
            ))
        else:
            old_text = read_file_at_tag(old_tag, old_acts[key])
            new_text = read_file_at_tag(new_tag, new_acts[key])
            if old_text == new_text:
                continue
            old_api = parse_action_api(old_text)
            new_api = parse_action_api(new_text)
            if not old_api or not new_api:
                continue

            fd = FileDiff(
                key=key, kind="action", status="changed",
                name=new_api.name,
                input_changes=_diff_inputs(old_api.inputs, new_api.inputs),
                output_changes=_diff_outputs(old_api.outputs, new_api.outputs),
                pr_summaries=pr_summaries.get(new_acts[key], []),
            )
            fd.status = "changed" if fd.has_api_changes else "internal"
            diffs.append(fd)

    return diffs


# ---------------------------------------------------------------------------
# Markdown renderer
# ---------------------------------------------------------------------------


def _change_icon(change: str) -> str:
    """Return a Material icon with a hover tooltip for the change type."""
    mapping = {
        "added": ':material-plus:{ title="Added" }',
        "removed": ':material-minus:{ title="Removed" }',
        "modified": ':material-pencil:{ title="Modified" }',
    }
    return mapping[change]


def render_input_table(changes: list[InputChange]) -> list[str]:
    lines = [
        "| Input | Change | Details |",
        "|---|---|---|",
    ]
    for c in changes:
        lines.append(f"| `{c.name}` | {_change_icon(c.change)} | {c.details} |")
    return lines


def render_secret_table(changes: list[SecretChange]) -> list[str]:
    lines = [
        "| Secret | Change | Details |",
        "|---|---|---|",
    ]
    for c in changes:
        lines.append(f"| `{c.name}` | {_change_icon(c.change)} | {c.details} |")
    return lines


def render_output_table(changes: list[OutputChange]) -> list[str]:
    lines = [
        "| Output | Change |",
        "|---|---|",
    ]
    for c in changes:
        lines.append(f"| `{c.name}` | {_change_icon(c.change)} |")
    return lines


def render_version(
    tag: str,
    date: str,
    file_diffs: list[FileDiff],
    contributors: list[str],
    is_initial: bool = False,
) -> str:
    """Render a single version entry as markdown."""
    lines: list[str] = []
    lines.append(f"## {tag}")
    lines.append("")
    lines.append(f"_{date}_")
    lines.append("")

    if is_initial:
        lines.append(
            "Initial release. Versioned shared workflows for iOS and KMP projects."
        )
        lines.append("")
        wfs = [d for d in file_diffs if d.kind == "workflow"]
        if wfs:
            lines.append("### Workflows")
            lines.append("")
            for d in wfs:
                lines.append(f"- `{d.key}`")
            lines.append("")
        if contributors:
            lines.append(f"**Contributors:** {', '.join(contributors)}")
            lines.append("")
        return "\n".join(lines)

    # Classify diffs
    breaking = [d for d in file_diffs if d.has_breaking_changes]
    added = [d for d in file_diffs if d.status == "added"]
    removed = [d for d in file_diffs if d.status == "removed"]
    api_changed = [
        d for d in file_diffs
        if d.status == "changed" and not d.has_breaking_changes
    ]
    internal = [d for d in file_diffs if d.status == "internal"]

    # --- Breaking changes ---
    if breaking:
        lines.append("### Breaking changes")
        lines.append("")
        wf_breaking = [d for d in breaking if d.kind == "workflow"]
        act_breaking = [d for d in breaking if d.kind == "action"]

        for label, items in [("Workflows", wf_breaking), ("Actions", act_breaking)]:
            if not items:
                continue
            lines.append(f"#### {label}")
            lines.append("")
            for d in items:
                lines.append(f"- **`{d.key}`**")
                for c in d.input_changes:
                    if c.change == "removed":
                        lines.append(f"    - Removed input `{c.name}`")
                for c in d.secret_changes:
                    if c.change == "removed":
                        lines.append(f"    - Removed secret `{c.name}`")
                for c in d.output_changes:
                    if c.change == "removed":
                        lines.append(f"    - Removed output `{c.name}`")
            lines.append("")

    # --- New workflows & actions ---
    if added:
        lines.append("### New workflows & actions")
        lines.append("")
        for d in added:
            lines.append(f"- Added {d.kind} `{d.key}`")
        lines.append("")

    # --- Removed workflows & actions ---
    if removed:
        lines.append("### Removed workflows & actions")
        lines.append("")
        for d in removed:
            lines.append(f"- Removed {d.kind} `{d.key}`")
        lines.append("")

    # --- Input / secret / output changes (non-breaking) ---
    all_api_changed = api_changed + [
        d for d in breaking if d.has_api_changes
    ]
    if all_api_changed:
        lines.append("### Input changes")
        lines.append("")
        for d in sorted(all_api_changed, key=lambda x: x.key):
            lines.append(f"#### `{d.key}`")
            lines.append("")
            if d.input_changes:
                lines.extend(render_input_table(d.input_changes))
                lines.append("")
            if d.secret_changes:
                lines.extend(render_secret_table(d.secret_changes))
                lines.append("")
            if d.output_changes:
                lines.extend(render_output_table(d.output_changes))
                lines.append("")

    # --- Internal changes ---
    if internal:
        lines.append("### Internal changes")
        lines.append("")
        for d in internal:
            summary = ""
            if d.pr_summaries:
                # Use first PR summary as description
                summary = f" — {d.pr_summaries[0]}"
            lines.append(f"- `{d.key}`{summary}")
        lines.append("")

    # --- Contributors ---
    if contributors:
        lines.append(f"**Contributors:** {', '.join(contributors)}")
        lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Public API — used by generate-docs.py for the home page "What's New" section
# ---------------------------------------------------------------------------


def get_version_diff(version: str) -> tuple[str, list[FileDiff]] | None:
    """Return (previous_tag, diffs) for the given version tag.

    Returns None if version is not a tag, is the first tag, or is a
    re-tag of the same commit as its predecessor.
    """
    tags = get_sorted_tags()
    if version not in tags:
        return None
    idx = tags.index(version)
    if idx == 0:
        return None
    old_tag = tags[idx - 1]
    if _git("rev-parse", old_tag) == _git("rev-parse", version):
        return None
    return (old_tag, diff_tags(old_tag, version))


def get_head_diff() -> tuple[str, str, list[FileDiff]] | None:
    """Return (old_tag, version_label, diffs) for non-tag builds.

    First tries diffing HEAD against the latest tag (unreleased changes).
    If no new changes exist, falls back to showing the latest tag's own
    changes so branch previews still display useful content.
    Returns None if no tags exist.
    """
    tags = get_sorted_tags()
    if not tags:
        return None
    latest = tags[-1]

    # Try unreleased changes first
    diffs = diff_tags(latest, "HEAD")
    if diffs:
        return (latest, "main", diffs)

    # Fall back to the latest tag's own diff
    result = get_version_diff(latest)
    if result:
        old_tag, tag_diffs = result
        return (old_tag, latest, tag_diffs)

    return None


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    tags = get_sorted_tags()
    if not tags:
        print("No version tags found.", file=sys.stderr)
        sys.exit(1)

    print(f"Found {len(tags)} tags: {', '.join(tags)}")

    entries: list[str] = []

    for i, tag in enumerate(tags):
        date = get_tag_date(tag)

        if i == 0:
            # Initial release — list all workflows/actions as "added"
            wf_files = list_files_at_tag(tag, WORKFLOW_PREFIX, ".yml")
            diffs = []
            for p in wf_files:
                key = Path(p).stem
                if key in ("deploy-docs",):
                    continue
                api = parse_workflow_api(read_file_at_tag(tag, p))
                diffs.append(FileDiff(
                    key=key, kind="workflow", status="added",
                    name=api.name if api else key,
                ))
            contributors = get_contributors(None, tag)
            entries.append(render_version(tag, date, diffs, contributors, is_initial=True))
        else:
            old_tag = tags[i - 1]

            # Skip if tags point to the same commit
            old_sha = _git("rev-parse", old_tag)
            new_sha = _git("rev-parse", tag)
            if old_sha == new_sha:
                entries.append(
                    f"## {tag}\n\n_{date}_\n\n"
                    f"Same as {old_tag} (re-tagged).\n"
                )
                continue

            diffs = diff_tags(old_tag, tag)
            contributors = get_contributors(old_tag, tag)
            entries.append(render_version(tag, date, diffs, contributors))

        print(f"  Generated: {tag}")

    # Combine entries (newest first)
    header = "# Changelog\n\nAll notable changes to Futured CI/CD Workflows.\n\n"

    output = header + "\n---\n\n".join(reversed(entries))

    output_path = ROOT_DIR / "docs" / "changelog.md"
    output_path.write_text(output)
    print(f"\nWritten: {output_path.relative_to(ROOT_DIR)}")


if __name__ == "__main__":
    main()
