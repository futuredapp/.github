"""Auto-generate mkdocs.yml nav section from the config registry."""

from __future__ import annotations

from collections import Counter
from pathlib import Path


# Lookup table for category labels that appear differently in YAML titles.
# "iOS + KMP" is the display label, but YAML `name:` fields use "iOS KMP".
_LABEL_VARIANTS: dict[str, list[str]] = {
    "iOS + KMP": ["iOS + KMP", "iOS KMP"],
}

_RUNNER_PREFIXES = ["Self-hosted", "Cloud", "Combined"]

_ACRONYM_MAP: dict[str, str] = {
    "ios": "iOS",
    "kmp": "KMP",
    "jira": "JIRA",
    "pr": "PR",
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _title_case(text: str) -> str:
    """Title-case *text* while preserving known acronyms (iOS, KMP, JIRA, PR)."""
    words = text.split()
    result: list[str] = []
    for word in words:
        # Separate leading/trailing punctuation (e.g. "(Deprecated)", "&")
        prefix = ""
        suffix = ""
        core = word
        while core and not core[0].isalnum():
            prefix += core[0]
            core = core[1:]
        while core and not core[-1].isalnum():
            suffix = core[-1] + suffix
            core = core[:-1]

        lower = core.lower()
        if lower in _ACRONYM_MAP:
            result.append(prefix + _ACRONYM_MAP[lower] + suffix)
        elif core:
            result.append(prefix + core[0].upper() + core[1:] + suffix)
        else:
            result.append(word)
    return " ".join(result)


def derive_nav_title(
    title: str,
    category: str,
    category_labels: dict[str, str],
) -> str:
    """Derive a short nav title by stripping category and runner prefixes.

    Strips the category label (e.g. "iOS", "Android") and runner prefix
    ("Self-hosted", "Cloud") from the full YAML title, then title-cases
    the remainder.  Falls back to the original title if stripping produces
    an empty string.
    """
    label = category_labels.get(category, "")
    variants = _LABEL_VARIANTS.get(label, [label]) if label else []

    stripped = title
    for variant in variants:
        if stripped.startswith(variant + " "):
            stripped = stripped[len(variant) :].strip()
            break

    for runner in _RUNNER_PREFIXES:
        if stripped.startswith(runner + " "):
            stripped = stripped[len(runner) :].strip()
            break

    if not stripped:
        return _title_case(title)

    return _title_case(stripped)


def _disambiguate_duplicates(entries: list[dict]) -> None:
    """Prepend runner type when two entries share the same nav title.

    Mutates *entries* in place.  Runner type is derived from the output
    path stem (e.g. ``cloud-backup`` -> "Cloud Backup").
    """
    title_counts = Counter(e["nav_title"] for e in entries)
    duplicates = {t for t, c in title_counts.items() if c > 1}
    if not duplicates:
        return

    for entry in entries:
        if entry["nav_title"] not in duplicates:
            continue
        stem = Path(entry["path"]).stem
        if stem.startswith("cloud-"):
            entry["nav_title"] = f"Cloud {entry['nav_title']}"
        elif stem.startswith("selfhosted-"):
            entry["nav_title"] = f"Self-hosted {entry['nav_title']}"
        elif stem.startswith("combined-"):
            entry["nav_title"] = f"Combined {entry['nav_title']}"


# ---------------------------------------------------------------------------
# Nav builder
# ---------------------------------------------------------------------------


def _build_type_section(
    registry: dict[str, dict],
    category_labels: dict[str, str],
    doc_type: str,
) -> list:
    """Build the nav sub-tree for either workflows or actions."""
    section: list = [{"Overview": f"{doc_type}/index.md"}]

    # Group entries by category.
    by_category: dict[str, list[tuple[str, dict]]] = {}
    for key, cfg in registry.items():
        by_category.setdefault(cfg["category"], []).append((key, cfg))

    # Walk categories in CATEGORY_LABELS order (preserves intended ordering).
    for cat_id, cat_label in category_labels.items():
        if cat_id not in by_category:
            continue

        cat_items: list = [f"{doc_type}/{cat_id}/index.md"]

        nav_entries: list[dict] = []
        for key, cfg in by_category[cat_id]:
            if "nav_title" in cfg:
                nav_title = cfg["nav_title"]
            else:
                nav_title = derive_nav_title(cfg["title"], cat_id, category_labels)
            rel_path = cfg["output"].removeprefix("docs/")
            nav_entries.append({"key": key, "nav_title": nav_title, "path": rel_path})

        _disambiguate_duplicates(nav_entries)
        nav_entries.sort(key=lambda e: e["nav_title"])

        for entry in nav_entries:
            cat_items.append({entry["nav_title"]: entry["path"]})

        section.append({cat_label: cat_items})

    return section


def build_nav(
    workflows: dict[str, dict],
    actions: dict[str, dict],
    category_labels: dict[str, str],
) -> list:
    """Build the full ``nav`` structure as a nested Python list.

    The returned list mirrors mkdocs' nav format and can be rendered to
    YAML with :func:`render_nav_yaml`.
    """
    return [
        {"Home": "index.md"},
        {"Workflows": _build_type_section(workflows, category_labels, "workflows")},
        {"Actions": _build_type_section(actions, category_labels, "actions")},
    ]


# ---------------------------------------------------------------------------
# YAML renderer
# ---------------------------------------------------------------------------


def _render_list(lines: list[str], items: list, indent: int) -> None:
    prefix = " " * indent
    for item in items:
        if isinstance(item, str):
            lines.append(f"{prefix}- {item}")
        elif isinstance(item, dict):
            key, value = next(iter(item.items()))
            if isinstance(value, str):
                lines.append(f"{prefix}- {key}: {value}")
            elif isinstance(value, list):
                lines.append(f"{prefix}- {key}:")
                _render_list(lines, value, indent + 4)


def render_nav_yaml(nav: list) -> str:
    """Render a nav structure to a YAML string.

    Uses a simple custom renderer instead of PyYAML to avoid
    ``!!python/name:`` tag issues in other parts of mkdocs.yml.
    """
    lines = ["nav:"]
    _render_list(lines, nav, indent=2)
    return "\n".join(lines) + "\n"


# ---------------------------------------------------------------------------
# Injection
# ---------------------------------------------------------------------------


def inject_nav(mkdocs_path: str | Path, nav_yaml: str) -> None:
    """Replace the ``nav:`` section in *mkdocs_path* with *nav_yaml*.

    Finds the ``nav:`` line at column 0, then the next top-level key,
    and replaces everything in between.
    """
    path = Path(mkdocs_path)
    lines = path.read_text().splitlines(keepends=True)

    nav_start: int | None = None
    nav_end: int | None = None

    for i, line in enumerate(lines):
        if nav_start is None:
            if line.startswith("nav:"):
                nav_start = i
        elif line.strip() and not line[0].isspace():
            nav_end = i
            break

    if nav_start is None:
        raise ValueError("Could not find 'nav:' at column 0 in mkdocs.yml")
    if nav_end is None:
        nav_end = len(lines)

    before = "".join(lines[:nav_start])
    after = "".join(lines[nav_end:])

    path.write_text(before + nav_yaml + "\n" + after)
