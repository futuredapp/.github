"""Abstract base class for documentation enrichers."""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class EnrichmentResult:
    """Result of an enrichment pass on a workflow or action spec."""

    additional_description: str | None = None
    usage_tips: str | None = None
    examples: list[str] = field(default_factory=list)


class BaseEnricher(ABC):
    """Interface for documentation enrichers.

    Enrichers augment auto-generated documentation with additional content
    beyond what the YAML metadata provides. They run in sequence; each
    enricher receives the results of all prior enrichers so it can avoid
    duplicating content.
    """

    @abstractmethod
    def name(self) -> str:
        """Human-readable name for this enricher."""
        ...

    @abstractmethod
    def can_enrich(self, spec: object, config: dict) -> bool:
        """Return True if this enricher has content to add for the given spec."""
        ...

    @abstractmethod
    def enrich(
        self,
        spec: object,
        config: dict,
        prior_results: list[EnrichmentResult],
    ) -> EnrichmentResult:
        """Produce enrichment content for the given spec.

        Args:
            spec: A WorkflowSpec or ActionSpec instance.
            config: The registry entry dict for this item.
            prior_results: Results from enrichers that ran before this one.

        Returns:
            An EnrichmentResult with any additional content to inject.
        """
        ...
