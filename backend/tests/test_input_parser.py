import sys
import unittest

sys.path.insert(0, "backend")

from services.input_parser import InputParser
from services.source_platform_adapters import default_source_adapters


class InputParserTests(unittest.TestCase):
    def setUp(self) -> None:
        self.parser = InputParser(default_source_adapters())

    def test_parses_supported_spotify_link(self) -> None:
        result = self.parser.parse("https://open.spotify.com/track/6qxvy9Pe4RJIq5JBVbbwbS")
        self.assertEqual(result.kind, "parsed")
        self.assertEqual(result.parsed_source.platform, "Spotify")

    def test_marks_missing_resource_for_apple_link_without_track_id(self) -> None:
        result = self.parser.parse("https://music.apple.com/cn/album/example")
        self.assertEqual(result.kind, "missing_resource")

    def test_marks_plain_text_as_reserved(self) -> None:
        result = self.parser.parse("Maroon Taylor Swift")
        self.assertEqual(result.kind, "plain_text")

    def test_extracts_qq_link_from_share_copy(self) -> None:
        extracted = self.parser._extract_candidate_link(
            "bôa《Duvet》 https://c6.y.qq.com/base/fcgi-bin/u?__=EMFvmMRMagAV @QQ音乐"
        )
        self.assertEqual(extracted, "https://c6.y.qq.com/base/fcgi-bin/u?__=EMFvmMRMagAV")

    def test_extracts_netease_link_from_share_copy(self) -> None:
        extracted = self.parser._extract_candidate_link(
            "分享George Michael的单曲《Careless Whisper》https://163cn.tv/44SdnwW (@网易云音乐)"
        )
        self.assertEqual(extracted, "https://163cn.tv/44SdnwW")