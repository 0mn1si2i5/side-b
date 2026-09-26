import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, "backend")

from models.resolver_models import ParsedSource, ResolverContext
from resolvers.spotify_platform import _SpotifyMetadataParser
from services.source_platform_adapters import SpotifySourceAdapter


class SpotifyPublicMetadataTests(unittest.TestCase):
    def test_parser_reads_public_track_meta_fields(self) -> None:
        parser = _SpotifyMetadataParser()
        parser.feed("""
          <meta property="og:title" content="Lost" />
          <meta property="og:description" content="Frank Ocean · channel ORANGE · Song · 2012" />
          <meta property="og:image" content="https://i.scdn.co/image/cover" />
          <meta name="music:duration" content="234" />
          <meta name="music:musician_description" content="Frank Ocean" />
        """)
        self.assertEqual(parser.values["og:title"], "Lost")
        self.assertEqual(parser.values["music:musician_description"], "Frank Ocean")

    @patch("services.source_platform_adapters.fetch_spotify_public_metadata")
    def test_source_adapter_falls_back_without_api_credentials(self, public_metadata) -> None:
        public_metadata.return_value = {
            "name": "Lost",
            "artists": [{"name": "Frank Ocean"}],
            "album": {
                "name": "channel ORANGE",
                "images": [{"url": "https://i.scdn.co/image/cover"}],
            },
            "duration_ms": 234000,
            "external_urls": {"spotify": "https://open.spotify.com/track/example"},
            "external_ids": {},
        }
        parsed = ParsedSource(
            raw_link="https://open.spotify.com/track/example",
            normalized_link="https://open.spotify.com/track/example",
            platform="Spotify",
            source_url="https://open.spotify.com/track/example",
            resource_id="example",
        )
        track = SpotifySourceAdapter().fetch_canonical_track(
            parsed,
            ResolverContext(preferred_market="CN", spotify_access_token=None),
        )
        self.assertEqual(track.title, "Lost")
        self.assertEqual(track.artist_name, "Frank Ocean")
        self.assertEqual(track.album_title, "channel ORANGE")
        self.assertEqual(track.duration_ms, 234000)
        public_metadata.assert_called_once_with("example")


if __name__ == "__main__":
    unittest.main()
