"""Auto-discovered registry of workflows and actions for documentation."""

from __future__ import annotations

from pathlib import Path

import yaml

ROOT_DIR = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Manual configuration
# ---------------------------------------------------------------------------

CATEGORY_LABELS: dict[str, str] = {
    "ios": "iOS",
    "ios-kmp": "iOS + KMP",
    "android": "Android",
    "kmp": "KMP",
    "universal": "Universal",
    "utility": "Utility",
}

EXCLUDE: set[str] = {"deploy-docs"}

# Per-entry overrides keyed by workflow/action name (filename stem or dir name).
# Any key set here replaces the auto-discovered value.
#
# Supported keys (workflows):
#   source             – relative path to the YAML file
#   category           – category id (must exist in CATEGORY_LABELS)
#   title              – display title (default: YAML `name:` field)
#   output             – output markdown path
#   runner             – runner label shown in docs
#   not_reusable       – bool; True hides the "Usage" snippet (auto-detected
#                        when `workflow_call` trigger is absent)
#   deprecated         – bool; True marks the workflow as deprecated
#   deprecated_message – markdown string shown in the deprecation banner
#
# Supported keys (actions):
#   source             – relative path to action.yml
#   category           – category id (must exist in CATEGORY_LABELS)
#   title              – display title (default: YAML `name:` field)
#   output             – output markdown path
#   readme             – relative path to a README.md to embed (auto-detected)
#
OVERRIDES: dict[str, dict] = {
    "ios-selfhosted-build": {
        "title": "iOS Build (Deprecated)",
        "deprecated": True,
        "deprecated_message": "Use `ios-selfhosted-nightly-build` instead.",
    },
    "workflows-lint": {
        "not_reusable": True,
    },
}

# Ordered longest-first so "ios-kmp" matches before "ios".
CATEGORY_PREFIXES: list[str] = sorted(
    ["ios-kmp", "ios", "android", "kmp", "universal"],
    key=len,
    reverse=True,
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _match_category(key: str, fallback: str) -> tuple[str, str]:
    """Return (category, slug) by matching the longest category prefix.

    The slug is the remainder of *key* after stripping the prefix and its
    trailing hyphen.  If no prefix matches, *fallback* is used as category
    and the full key becomes the slug.
    """
    for prefix in CATEGORY_PREFIXES:
        if key.startswith(prefix + "-"):
            slug = key[len(prefix) + 1 :]
            return prefix, slug
        if key == prefix:
            return prefix, key
    return fallback, key


def _derive_runner(key: str, yaml_text: str) -> str:
    """Derive the runner label from filename convention, falling back to YAML."""
    if "-combined-" in key:
        return "Self-hosted + ubuntu-latest"
    if "-selfhosted-" in key:
        return "Self-hosted"
    if "-cloud-" in key:
        return "ubuntu-latest"

    # Fallback: parse first runs-on value from YAML.
    for line in yaml_text.splitlines():
        stripped = line.strip()
        if stripped.startswith("runs-on:"):
            value = stripped.split(":", 1)[1].strip()
            # Normalise common variations.
            if "self-hosted" in value.lower():
                return "Self-hosted"
            return value
    return "ubuntu-latest"


def _parse_yaml_name(path: Path) -> str:
    """Return the top-level ``name`` field from a YAML file."""
    with open(path) as f:
        data = yaml.safe_load(f)
    if data and isinstance(data, dict):
        return data.get("name", path.stem)
    return path.stem


def _has_workflow_call(path: Path) -> bool:
    """Return True if the workflow declares a ``workflow_call`` trigger."""
    with open(path) as f:
        text = f.read()
    return "workflow_call" in text


# ---------------------------------------------------------------------------
# Auto-discovery
# ---------------------------------------------------------------------------


def discover_workflows(root: Path) -> dict[str, dict]:
    """Scan ``workflows/*.yml`` and build the config dict."""
    workflows: dict[str, dict] = {}
    workflows_dir = root / "workflows"
    if not workflows_dir.is_dir():
        return workflows

    for path in sorted(workflows_dir.glob("*.yml")):
        key = path.stem
        if key in EXCLUDE:
            continue

        category, slug = _match_category(key, "universal")
        title = _parse_yaml_name(path)

        with open(path) as f:
            yaml_text = f.read()
        runner = _derive_runner(key, yaml_text)

        entry: dict = {
            "source": f"workflows/{path.name}",
            "category": category,
            "title": title,
            "output": f"docs/workflows/{category}/{slug}.md",
            "runner": runner,
        }

        if not _has_workflow_call(path):
            entry["not_reusable"] = True

        # Merge overrides on top.
        if key in OVERRIDES:
            entry.update(OVERRIDES[key])

        workflows[key] = entry

    return workflows


def discover_actions(root: Path) -> dict[str, dict]:
    """Scan ``actions/*/action.yml`` and build the config dict."""
    actions: dict[str, dict] = {}
    actions_dir = root / "actions"
    if not actions_dir.is_dir():
        return actions

    for path in sorted(actions_dir.glob("*/action.yml")):
        key = path.parent.name
        category, slug = _match_category(key, "utility")
        title = _parse_yaml_name(path)

        entry: dict = {
            "source": f"actions/{key}/action.yml",
            "category": category,
            "title": title,
            "output": f"docs/actions/{category}/{slug}.md",
        }

        readme = path.parent / "README.md"
        if readme.exists():
            entry["readme"] = f"actions/{key}/README.md"

        # Merge overrides on top.
        if key in OVERRIDES:
            entry.update(OVERRIDES[key])

        actions[key] = entry

    return actions


# ---------------------------------------------------------------------------
# Exported registries (same interface as before)
# ---------------------------------------------------------------------------

WORKFLOWS: dict[str, dict] = discover_workflows(ROOT_DIR)
ACTIONS: dict[str, dict] = discover_actions(ROOT_DIR)
