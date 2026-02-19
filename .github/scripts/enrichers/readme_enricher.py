"""Enricher that extracts content from existing README files."""

from __future__ import annotations

import re
from pathlib import Path

from .base import BaseEnricher, EnrichmentResult


class ReadmeEnricher(BaseEnricher):
    """Extracts documentation sections from existing README.md files.

    For actions that already have hand-written READMEs (e.g.
    jira-transition-tickets, universal-detect-changes-and-generate-changelog),
    this enricher pulls in sections that go beyond what the YAML metadata
    provides — How It Works, Usage Examples, Testing, architecture details, etc.
    """

    def __init__(self, base_dir: str | Path) -> None:
        self._base_dir = Path(base_dir)

    def name(self) -> str:
        return "readme"

    def can_enrich(self, spec: object, config: dict) -> bool:
        return "readme" in config

    def enrich(
        self,
        spec: object,
        config: dict,
        prior_results: list[EnrichmentResult],
    ) -> EnrichmentResult:
        readme_path = self._base_dir / config["readme"]
        if not readme_path.exists():
            return EnrichmentResult()

        content = readme_path.read_text(encoding="utf-8")

        # Extract sections beyond Inputs/Outputs (those are already in the
        # generated tables). Keep sections like How It Works, Usage Examples,
        # Testing, Features, Scripts, etc.
        skip_headings = {
            "inputs",
            "outputs",
            "overview",  # Usually duplicates description
        }

        sections: list[str] = []
        current_section: list[str] = []
        current_heading = ""
        in_skip = False
        in_code_fence = False

        for line in content.splitlines():
            # Track fenced code blocks to avoid matching headings inside them
            if line.startswith("```"):
                in_code_fence = not in_code_fence
                if not in_skip:
                    current_section.append(line)
                continue

            if in_code_fence:
                if not in_skip:
                    current_section.append(line)
                continue

            heading_match = re.match(r"^(#{1,3})\s+(.+)", line)
            if heading_match:
                # Save previous section if not skipped
                if current_section and not in_skip:
                    sections.append("\n".join(current_section))

                current_heading = heading_match.group(2).strip()
                heading_key = re.sub(r"[`*]", "", current_heading).lower()

                # Skip the title line (first H1) and known metadata sections
                level = len(heading_match.group(1))
                if level == 1:
                    in_skip = True
                    current_section = []
                    continue

                in_skip = heading_key in skip_headings
                current_section = [line] if not in_skip else []
            else:
                if not in_skip:
                    current_section.append(line)

        # Don't forget the last section
        if current_section and not in_skip:
            sections.append("\n".join(current_section))

        additional = "\n\n".join(s.strip() for s in sections if s.strip())

        # Extract usage examples separately
        examples: list[str] = []
        example_blocks = re.findall(
            r"```yaml\n(.*?)```", content, re.DOTALL
        )
        for block in example_blocks:
            examples.append(block.strip())

        return EnrichmentResult(
            additional_description=additional if additional else None,
            examples=examples if examples else [],
        )
