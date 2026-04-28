import sys
import unittest

sys.path.insert(0, "backend")

from models.resolver_models import CanonicalTrack, ParsedSource
from services.input_parser import InputParser, InputParseResult
from services.resolver_service import ResolverService


class FakeAdapter:
    platform = "Apple Music"

    def can_handle(self, raw_link: str) -> bool:
        return True

    def parse_source_link(self, raw_link: str):
        return ParsedSource(
            raw_link=raw_link,
            normalized_link=raw_link.lower(),
            platform=self.platform,
            source_url=raw_link,
            resource_id="apple-id",
        )

    def fetch_canonical_track(self, parsed_source, context):
        return CanonicalTrack(
            source_platform="Apple Music",
            source_id="apple-id",
            source_url=parsed_source.source_url,
            title="Song",
            artist_name="Artist",
            album_title="Album",
            duration_ms=123000,
            artwork_url=None,
            isrc=None,
        )


class FailingMetadataAdapter(FakeAdapter):
    platform = "QQ 音乐"

    def fetch_canonical_track(self, parsed_source, context):
        raise RuntimeError("third-party service unavailable")


class FakeInputParser(InputParser):
    def __init__(self, adapter=None):
        self.adapter = adapter or FakeAdapter()

    def parse(self, raw_input: str):
        return InputParseResult(
            kind="parsed",
            raw_input=raw_input,
            adapter=self.adapter,
            parsed_source=self.adapter.parse_source_link(raw_input),
        )


class FakeResolverService(ResolverService):
    def build_context(self, preferred_market):
        context = super().build_context(preferred_market)
        context.spotify_access_token = None
        return context


class ResolverServiceTests(unittest.TestCase):
    def test_resolve_metadata_only_returns_source_link_only(self) -> None:
        service = FakeResolverService(
            input_parser=FakeInputParser(),
            source_adapters=[FakeAdapter()],
            target_resolvers=[],
        )

        response = service.resolve("https://music.apple.com/test", preferred_market=None, include_platform_links=False)
        self.assertEqual(response["status_code"], 200)
        self.assertEqual(len(response["body"]["resolvedTrack"]["platformLinks"]), 1)
        self.assertEqual(response["body"]["resolvedTrack"]["sourcePlatform"], "Apple Music")

    def test_plain_text_returns_reserved_error(self) -> None:
        service = ResolverService()
        response = service.resolve("Maroon Taylor Swift", preferred_market=None, include_platform_links=False)
        self.assertEqual(response["status_code"], 400)
        self.assertIn("reserved", response["body"]["error"])

    def test_source_metadata_failure_returns_diagnostic_response(self) -> None:
        adapter = FailingMetadataAdapter()
        service = FakeResolverService(
            input_parser=FakeInputParser(adapter),
            source_adapters=[adapter],
            target_resolvers=[],
        )

        response = service.resolve("https://c6.y.qq.com/test", preferred_market=None, include_platform_links=False)

        self.assertEqual(response["status_code"], 502)
        self.assertEqual(response["body"]["metadataStatus"], "failed")
        self.assertIn("QQ", response["body"]["error"])
