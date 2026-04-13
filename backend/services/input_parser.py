from __future__ import annotations

from dataclasses import dataclass

from models.resolver_models import ParsedSource, SourcePlatformAdapter
from services.source_platform_adapters import default_source_adapters


@dataclass(frozen=True)
class InputParseResult:
    kind: str
    raw_input: str
    adapter: SourcePlatformAdapter | None = None
    parsed_source: ParsedSource | None = None


class InputParser:
    def __init__(self, adapters: list[SourcePlatformAdapter] | None = None) -> None:
        self.adapters = adapters or default_source_adapters()

    def parse(self, raw_input: str) -> InputParseResult:
        normalized_input = raw_input.strip()
        if not normalized_input:
            return InputParseResult(kind="unsupported", raw_input=raw_input)

        adapter = next((candidate for candidate in self.adapters if candidate.can_handle(normalized_input)), None)
        if adapter is None:
            if self._looks_like_plain_text(normalized_input):
                return InputParseResult(kind="plain_text", raw_input=raw_input)
            return InputParseResult(kind="unsupported", raw_input=raw_input)

        parsed_source = adapter.parse_source_link(normalized_input)
        if parsed_source is None:
            return InputParseResult(kind="missing_resource", raw_input=raw_input, adapter=adapter)

        return InputParseResult(
            kind="parsed",
            raw_input=raw_input,
            adapter=adapter,
            parsed_source=parsed_source,
        )

    @staticmethod
    def _looks_like_plain_text(raw_input: str) -> bool:
        return "://" not in raw_input and "." not in raw_input
