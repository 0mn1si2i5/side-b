import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, "backend")

from models.resolver_models import CanonicalTrack, ResolverContext
from services.platform_link_resolvers import NeteaseTargetResolver, qq_candidate_score


class PlatformLinkResolverTests(unittest.TestCase):
    def test_qq_candidate_score_prefers_exact_match(self) -> None:
        exact_candidate = {
            "title": "Maroon",
            "artist_name": "Taylor Swift",
            "album_title": "Midnights (The Til Dawn Edition)",
            "duration_ms": 218270,
        }
        loose_candidate = {
            "title": "Maroon (Live)",
            "artist_name": "Taylor Swift",
            "album_title": "Various Artists",
            "duration_ms": 219000,
        }

        exact_score = qq_candidate_score(
            exact_candidate,
            title="Maroon",
            artist_name="Taylor Swift",
            album_title="Midnights (The Til Dawn Edition)",
            duration_ms=218270,
            query_rank=0,
        )
        loose_score = qq_candidate_score(
            loose_candidate,
            title="Maroon",
            artist_name="Taylor Swift",
            album_title="Midnights (The Til Dawn Edition)",
            duration_ms=218270,
            query_rank=0,
        )

        self.assertGreater(exact_score, loose_score)

    def test_netease_resolver_does_not_cache_outage_as_missing_link(self) -> None:
        cache_store: dict = {}
        context = ResolverContext(
            preferred_market=None,
            spotify_access_token=None,
            netease_api_base_url="http://127.0.0.1:3000",
            cache_stores={"netease_links": cache_store},
        )
        track = CanonicalTrack(
            source_platform="Spotify",
            source_id="spotify-id",
            source_url="https://open.spotify.com/track/test",
            title="Song",
            artist_name="Artist",
            album_title="Album",
            duration_ms=180000,
            artwork_url=None,
            isrc=None,
        )

        with patch("services.platform_link_resolvers.search_tracks", side_effect=ConnectionRefusedError("down")):
            resolved_url = NeteaseTargetResolver().resolve_link(track, context)

        self.assertIsNone(resolved_url)
        self.assertEqual(cache_store, {})
