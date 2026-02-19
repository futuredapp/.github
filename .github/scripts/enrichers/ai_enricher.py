"""AI-powered documentation enricher (stub).

This enricher is a documented no-op that serves as the integration point
for future AI-generated documentation. When activated, it will use an LLM
to generate additional descriptions, usage tips, and examples for workflows
and actions that lack hand-written READMEs.

Activation:
    Pass ``--enrich`` flag to ``generate-docs.py`` AND set the
    ``AI_DOCS_API_KEY`` environment variable. Optionally provide
    ``--ai-config path/to/config.json`` with the following structure::

        {
            "api_key_env": "AI_DOCS_API_KEY",
            "model": "claude-sonnet-4-20250514",
            "prompt_template": "scripts/templates/ai_prompt.txt",
            "max_tokens": 1024
        }

Implementation notes for future activation:
    1. Read the source YAML file content for the spec.
    2. Construct a prompt from the template with the YAML content and
       existing enrichment results.
    3. Call the AI API to generate additional documentation.
    4. Parse the response into an EnrichmentResult.
"""

from __future__ import annotations

import json
import os
from pathlib import Path

from .base import BaseEnricher, EnrichmentResult


class AIEnricher(BaseEnricher):
    """AI-powered enricher — currently a documented no-op.

    Activates only when ``--enrich`` flag is passed AND the API key
    environment variable is set. Without both conditions met, this
    enricher silently produces empty results.
    """

    def __init__(
        self,
        enabled: bool = False,
        config_path: str | Path | None = None,
    ) -> None:
        self._enabled = enabled
        self._config: dict = {}

        if config_path and Path(config_path).exists():
            with open(config_path) as f:
                self._config = json.load(f)

        # Check for API key
        api_key_env = self._config.get("api_key_env", "AI_DOCS_API_KEY")
        self._api_key = os.environ.get(api_key_env, "")

    def name(self) -> str:
        return "ai"

    def can_enrich(self, spec: object, config: dict) -> bool:
        return self._enabled and bool(self._api_key)

    def enrich(
        self,
        spec: object,
        config: dict,
        prior_results: list[EnrichmentResult],
    ) -> EnrichmentResult:
        # Stub — no-op until AI integration is implemented.
        # When implementing, use self._config for model/prompt settings
        # and self._api_key for authentication.
        return EnrichmentResult()
