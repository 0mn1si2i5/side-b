import unittest
from unittest.mock import patch
from resolvers.spotify_platform import fetch_spotify_track_url


class SpotifySearchRecoveryTests(unittest.TestCase):
    def resolve(self, cache):
        return fetch_spotify_track_url(source_url="https://music.apple.com/sg/song/1", title="No Surprises", artist_name="Radiohead", album_title="OK Computer", duration_ms=229000, preferred_market="SG", access_token="test", cache_store=cache)

    def test_outage_is_not_cached_and_next_request_can_recover(self):
        cache = {}
        with patch("resolvers.spotify_platform.fetch_spotify_search_candidates", side_effect=ConnectionError("offline")):
            with self.assertRaises(ConnectionError):
                self.resolve(cache)
        self.assertEqual(cache, {})
        song = {"name": "No Surprises", "artists": [{"name": "Radiohead"}], "album": {"name": "OK Computer"}, "duration_ms": 229000, "external_urls": {"spotify": "https://open.spotify.com/track/example"}}
        with patch("resolvers.spotify_platform.fetch_spotify_search_candidates", return_value=[song]):
            self.assertEqual(self.resolve(cache), song["external_urls"]["spotify"])

    def test_successful_empty_search_remains_missing(self):
        cache = {}
        with patch("resolvers.spotify_platform.fetch_spotify_search_candidates", return_value=[]):
            self.assertIsNone(self.resolve(cache))
        self.assertTrue(cache)
