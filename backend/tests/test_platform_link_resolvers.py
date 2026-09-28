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
            with self.assertRaises(ConnectionRefusedError):
                NeteaseTargetResolver().resolve_link(track, context)

        self.assertEqual(cache_store, {})

class PlatformRecoveryTests(unittest.TestCase):
    def track(self):
        return CanonicalTrack(source_platform="Apple Music", source_id="1", source_url="https://music.apple.com/sg/song/1", title="No Surprises", artist_name="Radiohead", album_title="OK Computer", duration_ms=229000, artwork_url=None, isrc=None)

    def test_public_netease_catalog_does_not_need_a_companion_service(self):
        context = ResolverContext(preferred_market="SG", spotify_access_token=None, netease_api_base_url=None)
        song = {"id": 22497479, "name": "No Surprises", "artists": [{"name": "Radiohead"}], "album": {"name": "OK Computer"}, "duration": 229000}
        with patch("services.platform_link_resolvers.search_public_tracks", return_value=[song]) as search, patch("services.platform_link_resolvers.check_music") as playable:
            self.assertEqual(NeteaseTargetResolver().resolve_link(self.track(), context), "https://music.163.com/#/song?id=22497479")
            self.assertTrue(search.called)
            playable.assert_not_called()

    def test_platform_outages_remain_distinct_from_missing_matches(self):
        from types import SimpleNamespace
        from services.platform_link_resolvers import resolve_platform_links_with_results
        context = ResolverContext(preferred_market="SG", spotify_access_token=None, netease_api_base_url=None)
        def fail(*_args):
            raise ConnectionError("offline")
        resolvers = [SimpleNamespace(platform="Spotify", resolve_link=lambda *_: None), SimpleNamespace(platform="QQ 音乐", resolve_link=fail), SimpleNamespace(platform="网易云音乐", resolve_link=lambda *_: "https://music.163.com/song?id=22497479")]
        with patch("services.platform_link_resolvers.settings.SONGLINK_API_KEY", ""):
            links, results = resolve_platform_links_with_results(self.track(), context, resolvers)
        self.assertEqual(links[0]["destinationURL"], self.track().source_url)
        self.assertEqual({item["platform"]: item["status"] for item in results}, {"Apple Music": "matched", "Spotify": "unavailable", "QQ 音乐": "failed", "网易云音乐": "matched"})
