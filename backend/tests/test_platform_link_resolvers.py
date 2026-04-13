import sys
import unittest

sys.path.insert(0, "backend")

from services.platform_link_resolvers import qq_candidate_score


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
