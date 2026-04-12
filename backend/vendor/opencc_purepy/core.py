import re
from enum import Enum
from multiprocessing import Pool, cpu_count

try:
    from typing import List, Dict, Tuple, Optional, Union
except ImportError:
    # Fallback for Python < 3.5
    # Very old Python fallback:
    # these names only need to exist so runtime does not fail.
    List = list
    Dict = dict
    Tuple = tuple


    class _TypingStub(object):
        def __getitem__(self, item):
            return object


    Optional = _TypingStub()
    Union = _TypingStub()

from .dictionary_lib import DictionaryMaxlength

# Pre-compiled regex for better performance
STRIP_REGEX = re.compile(r"[!-/:-@\[-`{-~\t\n\v\f\r 0-9A-Za-z_著]")

DELIMITERS = frozenset(
    " \t\n\r!\"#$%&'()*+,-./:;<=>?@[\\]^_{}|~＝、。“”‘’『』「」﹁﹂—－（）《》〈〉？！…／＼︒︑︔︓︿﹀︹︺︙︐［﹇］﹈︕︖︰︳︴︽︾︵︶｛︷｝︸﹃﹄【︻】︼　～．，；：")

# Pre-computed punctuation mappings - fallback for older Python versions
try:
    PUNCT_S2T_MAP = str.maketrans({
        '“': '「',
        '”': '」',
        '‘': '『',
        '’': '』',
    })

    PUNCT_T2S_MAP = str.maketrans({
        '「': '“',
        '」': '”',
        '『': '‘',
        '』': '’',
    })
    HAS_MAKETRANS = True
except (AttributeError, TypeError):
    # Fallback for Python < 3.0
    HAS_MAKETRANS = False
    PUNCT_S2T_MAP = {
        '“': '「',
        '”': '」',
        '‘': '『',
        '’': '』',
    }

    PUNCT_T2S_MAP = {
        '「': '“',
        '」': '”',
        '『': '‘',
        '』': '’',
    }


class OpenccConfig(Enum):
    S2T = "s2t"
    T2S = "t2s"
    S2TW = "s2tw"
    TW2S = "tw2s"
    S2TWP = "s2twp"
    TW2SP = "tw2sp"
    S2HK = "s2hk"
    HK2S = "hk2s"
    T2TW = "t2tw"
    TW2T = "tw2t"
    T2TWP = "t2twp"
    TW2TP = "tw2tp"
    T2HK = "t2hk"
    HK2T = "hk2t"
    T2JP = "t2jp"
    JP2T = "jp2t"

    value: str

    def to_canonical_name(self) -> str:
        """Return OpenCC canonical config name (e.g. 's2t')."""
        return self.value

    @classmethod
    def parse(cls, s: str) -> "OpenccConfig":
        return cls(s.lower())


_ConfigLike = Optional[Union[str, OpenccConfig]]


class DictRefs:
    """
    A utility class that wraps up to 3 rounds of dictionary applications
    to be used in multi-pass segment-replacement conversions.
    """
    __slots__ = ['round_1', 'round_2', 'round_3', '_max_lengths']

    def __init__(self, round_1):
        """
        :param round_1: First list of dictionaries to apply (required)
        """
        self.round_1 = round_1
        self.round_2 = None
        self.round_3 = None
        self._max_lengths = None

    def with_round_2(self, round_2):
        """
        :param round_2: Second list of dictionaries (optional)
        :return: self (for chaining)
        """
        self.round_2 = round_2
        self._max_lengths = None  # Reset cache
        return self

    def with_round_3(self, round_3):
        """
        :param round_3: Third list of dictionaries (optional)
        :return: self (for chaining)
        """
        self.round_3 = round_3
        self._max_lengths = None  # Reset cache
        return self

    def _get_max_lengths(self):
        """Cache max lengths for each round to avoid recomputation"""
        if self._max_lengths is None:
            self._max_lengths = []
            for round_dicts in [self.round_1, self.round_2, self.round_3]:
                if round_dicts:
                    max_len = max((length for _, length in round_dicts), default=1)
                    self._max_lengths.append(max_len)
                else:
                    self._max_lengths.append(0)
        return self._max_lengths

    def apply_segment_replace(self, input_text, segment_replace):
        """
        Apply segment-based replacement using the configured rounds.

        :param input_text: The string to transform
        :param segment_replace: The function to apply per segment
        :return: Transformed string
        """
        max_lengths = self._get_max_lengths()

        output = segment_replace(input_text, self.round_1, max_lengths[0])
        if self.round_2:
            output = segment_replace(output, self.round_2, max_lengths[1])
        if self.round_3:
            output = segment_replace(output, self.round_3, max_lengths[2])
        return output


class OpenCC:
    """
    A pure-Python implementation of OpenCC for text conversion between
    different Chinese language variants using segmentation and replacement.
    """
    CONFIG_LIST = [c.value for c in OpenccConfig]

    def __init__(self, config: _ConfigLike = None):
        """
        Initialize OpenCC with a given config (default: s2t).

        :param config: Configuration name (optional)
        """
        self._last_error = None
        self._config_cache: Dict[str, DictRefs] = {}
        self.config = self._normalize_config(config)

        try:
            self.dictionary = DictionaryMaxlength.new()
        except Exception as e:
            self._last_error = str(e)
            self.dictionary = DictionaryMaxlength()

        self.delimiters = DELIMITERS
        # Escape special regex characters in delimiters
        escaped_delimiters = ''.join(map(re.escape, self.delimiters))
        self.delimiter_regex = re.compile(f'[{escaped_delimiters}]')

    def _normalize_config(self, config: _ConfigLike) -> str:
        """
        Normalize config to canonical lowercase OpenCC name.

        Returns:
            str: Valid canonical config name. Falls back to "s2t" if invalid.
        """
        if config is None:
            return "s2t"

        if isinstance(config, OpenccConfig):
            self._last_error = None
            return config.value

        if isinstance(config, str):
            cfg = config.strip().lower()
            if cfg in self.CONFIG_LIST:
                self._last_error = None
                return cfg

            self._last_error = "Invalid config: {}".format(config)
            return "s2t"

        self._last_error = "Invalid config: {}".format(config)
        return "s2t"

    def set_config(self, config: _ConfigLike) -> None:
        """
        Set the conversion configuration.

        :param config: Configuration name or OpenccConfig enum
        """
        self.config = self._normalize_config(config)

    def get_config(self):
        """
        Get the current conversion config.

        :return: Current config string
        """
        return self.config

    @classmethod
    def supported_configs(cls):
        """
        Return a list of supported conversion config strings.

        :return: List of config names
        """
        return cls.CONFIG_LIST

    def get_last_error(self):
        """
        Retrieve the last error message, if any.

        :return: Error string or None
        """
        return self._last_error

    def get_split_ranges(self, text: str, inclusive: bool = False) -> List[Tuple[int, int]]:
        """
        Split the input into ranges of text between delimiters using regex.

        If `inclusive` is True:
            - Each (start, end) range includes the delimiter (like forward mmseg).
        If `inclusive` is False:
            - Each (start, end) range excludes the delimiter.
            - Delimiters are returned as separate (start, end) segments.

        :param text: Input string
        :param inclusive: Whether to include delimiters in the same segment
        :return: List of (start, end) index pairs
        """
        ranges = []
        start = 0
        for match in self.delimiter_regex.finditer(text):
            delim_start, delim_end = match.start(), match.end()
            if inclusive:
                # Include delimiter in the same range
                ranges.append((start, delim_end))
            else:
                # Exclude delimiter from main segment, and add as its own
                if delim_start > start:
                    ranges.append((start, delim_start))
                ranges.append((delim_start, delim_end))
            start = delim_end

        if start < len(text):
            ranges.append((start, len(text)))

        return ranges

    def segment_replace(
            self,
            text: str,
            dictionaries: List[Tuple[Dict[str, str], int]],
            max_word_length: int
    ) -> str:
        """
        Perform dictionary-based greedy replacement on segmented text (legacy path).

        This version is simplified to work cleanly with DictRefs normalization:
        - No StarterIndex / fast-path logic.
        - Accepts a round's `dictionaries` as List[(dict, max_len)] and a round
          `max_word_length` (already computed by DictRefs).
        - Keeps the existing parallelization behavior.

        Parameters
        ----------
        text : str
            The input text to be converted.
        dictionaries : list of (dict, int)
            Sequence of dictionaries and their respective maximum key lengths.
            The order determines replacement precedence (earlier wins).
        max_word_length : int
            Global maximum match length for this round (from DictRefs).

        Returns
        -------
        str
            Converted text.
        """
        if not text:
            return text

        # Split into segments (inclusive keeps delimiters attached to segments)
        ranges = self.get_split_ranges(text, inclusive=True)

        # Single segment → direct convert (avoids slicing/join overhead)
        if len(ranges) == 1 and ranges[0] == (0, len(text)):
            return OpenCC.convert_segment(text, dictionaries, max_word_length)

        # Parallel threshold
        total_length = len(text)
        use_parallel = len(ranges) > 1_000 and total_length >= 1_000_000

        if use_parallel:
            group_count = min(4, max(1, cpu_count()))
            groups = chunk_ranges(ranges, group_count)
            with Pool(processes=group_count) as pool:
                results = pool.map(
                    convert_range_group,
                    [(text, group, dictionaries, max_word_length, OpenCC.convert_segment) for group in groups],
                )
            return "".join(results)

        # Serial path
        return "".join(
            OpenCC.convert_segment(text[s:e], dictionaries, max_word_length)
            for (s, e) in ranges
        )

    @staticmethod
    def convert_segment(segment: str, dictionaries, max_word_length: int) -> str:
        """
        Apply dictionary replacements to a text segment using greedy max-length matching.

        :param segment: Text segment to convert
        :param dictionaries: List of (dict, max_length) tuples
        :param max_word_length: Maximum matching word length
        :return: Converted string
        """
        if not segment or (len(segment) == 1 and segment in DELIMITERS):
            return segment

        result = []
        i = 0
        n = len(segment)

        while i < n:
            remaining = n - i
            best_match = None
            best_length = 0

            # Try matches from longest to shortest
            for length in range(min(max_word_length, remaining), 0, -1):
                end = i + length
                word = segment[i:end]

                # Check all dictionaries for this word
                for dict_data, max_len in dictionaries:
                    if max_len < length:
                        continue

                    match = dict_data.get(word)
                    if match is not None:
                        best_match = match
                        best_length = length
                        break

                if best_match:
                    break

            if best_match is not None:
                result.append(best_match)
                i += best_length
            else:
                result.append(segment[i])
                i += 1

        return ''.join(result)

    def _get_dict_refs(self, config_key: str) -> DictRefs:
        """Get cached DictRefs for a config to avoid recreation."""
        cached = self._config_cache.get(config_key)
        if cached is not None:
            return cached

        d = self.dictionary

        if config_key == "s2t":
            refs = DictRefs([d.st_phrases, d.st_characters])
        elif config_key == "t2s":
            refs = DictRefs([d.ts_phrases, d.ts_characters])
        elif config_key == "s2tw":
            refs = (
                DictRefs([d.st_phrases, d.st_characters])
                .with_round_2([d.tw_variants])
            )
        elif config_key == "tw2s":
            refs = (
                DictRefs([d.tw_variants_rev_phrases, d.tw_variants_rev])
                .with_round_2([d.ts_phrases, d.ts_characters])
            )
        elif config_key == "s2twp":
            refs = (
                DictRefs([d.st_phrases, d.st_characters])
                .with_round_2([d.tw_phrases])
                .with_round_3([d.tw_variants])
            )
        elif config_key == "tw2sp":
            refs = (
                DictRefs([d.tw_phrases_rev, d.tw_variants_rev_phrases, d.tw_variants_rev])
                .with_round_2([d.ts_phrases, d.ts_characters])
            )
        elif config_key == "s2hk":
            refs = (
                DictRefs([d.st_phrases, d.st_characters])
                .with_round_2([d.hk_variants])
            )
        elif config_key == "hk2s":
            refs = (
                DictRefs([d.hk_variants_rev_phrases, d.hk_variants_rev])
                .with_round_2([d.ts_phrases, d.ts_characters])
            )
        elif config_key == "t2tw":
            refs = DictRefs([d.tw_variants])
        elif config_key == "t2twp":
            refs = (
                DictRefs([d.tw_phrases])
                .with_round_2([d.tw_variants])
            )
        elif config_key == "tw2t":
            refs = DictRefs([d.tw_variants_rev_phrases, d.tw_variants_rev])
        elif config_key == "tw2tp":
            refs = (
                DictRefs([d.tw_variants_rev_phrases, d.tw_variants_rev])
                .with_round_2([d.tw_phrases_rev])
            )
        elif config_key == "t2hk":
            refs = DictRefs([d.hk_variants])
        elif config_key == "hk2t":
            refs = DictRefs([d.hk_variants_rev_phrases, d.hk_variants_rev])
        elif config_key == "t2jp":
            refs = DictRefs([d.jp_variants])
        elif config_key == "jp2t":
            refs = DictRefs([d.jps_phrases, d.jps_characters, d.jp_variants_rev])
        else:
            raise ValueError(f"Unsupported config: {config_key}")

        self._config_cache[config_key] = refs
        return refs

    @staticmethod
    def _convert_punctuation_legacy(text, punct_map):
        """
        (Fallback punctuation conversion for older Python versions)
        Convert between Simplified and Traditional punctuation styles.

        :param text: Input text
        :param punct_map: Conversion punctuation map
        :return: Text with punctuation converted
        """
        result = []
        for char in text:
            result.append(punct_map.get(char, char))
        return ''.join(result)

    def s2t(self, input_text, punctuation=False):
        """
        Convert Simplified Chinese to Traditional Chinese.

        :param input_text: The source string in Simplified Chinese
        :param punctuation: Whether to convert punctuation
        :return: Transformed string in Traditional Chinese
        """
        refs = self._get_dict_refs("s2t")
        output = refs.apply_segment_replace(input_text, self.segment_replace)

        if punctuation:
            if HAS_MAKETRANS:
                return output.translate(PUNCT_S2T_MAP)
            else:
                return self._convert_punctuation_legacy(output, PUNCT_S2T_MAP)
        return output

    def t2s(self, input_text, punctuation=False):
        """
        Convert Traditional Chinese to Simplified Chinese.

        :param input_text: The source string in Traditional Chinese
        :param punctuation: Whether to convert punctuation
        :return: Transformed string in Simplified Chinese
        """
        refs = self._get_dict_refs("t2s")
        output = refs.apply_segment_replace(input_text, self.segment_replace)

        if punctuation:
            if HAS_MAKETRANS:
                return output.translate(PUNCT_T2S_MAP)
            else:
                return self._convert_punctuation_legacy(output, PUNCT_T2S_MAP)
        return output

    def s2tw(self, input_text, punctuation=False):
        """
        Convert Simplified Chinese to Traditional Chinese (Taiwan Standard).

        :param input_text: The source string
        :param punctuation: Whether to convert punctuation
        :return: Transformed string in Taiwan Traditional Chinese
        """
        refs = self._get_dict_refs("s2tw")
        output = refs.apply_segment_replace(input_text, self.segment_replace)

        if punctuation:
            if HAS_MAKETRANS:
                return output.translate(PUNCT_S2T_MAP)
            else:
                return self._convert_punctuation_legacy(output, PUNCT_S2T_MAP)
        return output

    def tw2s(self, input_text, punctuation=False):
        """
        Convert Traditional Chinese (Taiwan) to Simplified Chinese.

        :param input_text: The source string in Taiwan Traditional Chinese
        :param punctuation: Whether to convert punctuation
        :return: Transformed string in Simplified Chinese
        """
        refs = self._get_dict_refs("tw2s")
        output = refs.apply_segment_replace(input_text, self.segment_replace)

        if punctuation:
            if HAS_MAKETRANS:
                return output.translate(PUNCT_T2S_MAP)
            else:
                return self._convert_punctuation_legacy(output, PUNCT_T2S_MAP)
        return output

    def s2twp(self, input_text, punctuation=False):
        """
        Convert Simplified Chinese to Traditional (Taiwan) using phrases + variants.

        :param input_text: The source string
        :param punctuation: Whether to convert punctuation
        :return: Transformed string
        """
        refs = self._get_dict_refs("s2twp")
        output = refs.apply_segment_replace(input_text, self.segment_replace)

        if punctuation:
            if HAS_MAKETRANS:
                return output.translate(PUNCT_S2T_MAP)
            else:
                return self._convert_punctuation_legacy(output, PUNCT_S2T_MAP)
        return output

    def tw2sp(self, input_text, punctuation=False):
        """
        Convert Traditional (Taiwan) with phrases to Simplified Chinese.

        :param input_text: The source string
        :param punctuation: Whether to convert punctuation
        :return: Transformed string
        """
        refs = self._get_dict_refs("tw2sp")
        output = refs.apply_segment_replace(input_text, self.segment_replace)

        if punctuation:
            if HAS_MAKETRANS:
                return output.translate(PUNCT_T2S_MAP)
            else:
                return self._convert_punctuation_legacy(output, PUNCT_T2S_MAP)
        return output

    def s2hk(self, input_text, punctuation=False):
        """
        Convert Simplified Chinese to Traditional (Hong Kong Standard).

        :param input_text: Simplified Chinese input
        :param punctuation: Whether to convert punctuation
        :return: Transformed string
        """
        refs = self._get_dict_refs("s2hk")
        output = refs.apply_segment_replace(input_text, self.segment_replace)

        if punctuation:
            if HAS_MAKETRANS:
                return output.translate(PUNCT_S2T_MAP)
            else:
                return self._convert_punctuation_legacy(output, PUNCT_S2T_MAP)
        return output

    def hk2s(self, input_text, punctuation=False):
        """
        Convert Traditional (Hong Kong) to Simplified Chinese.

        :param input_text: Hong Kong Traditional Chinese input
        :param punctuation: Whether to convert punctuation
        :return: Simplified Chinese output
        """
        refs = self._get_dict_refs("hk2s")
        output = refs.apply_segment_replace(input_text, self.segment_replace)

        if punctuation:
            if HAS_MAKETRANS:
                return output.translate(PUNCT_T2S_MAP)
            else:
                return self._convert_punctuation_legacy(output, PUNCT_T2S_MAP)
        return output

    def t2tw(self, input_text: str) -> str:
        """
        Convert Traditional Chinese to Taiwan Standard Traditional Chinese.
        """
        refs = self._get_dict_refs("t2tw")
        return refs.apply_segment_replace(input_text, self.segment_replace)

    def t2twp(self, input_text: str) -> str:
        """
        Convert Traditional Chinese to Taiwan Standard using phrase and variant mappings.
        """
        refs = self._get_dict_refs("t2twp")
        return refs.apply_segment_replace(input_text, self.segment_replace)

    def tw2t(self, input_text: str) -> str:
        """
        Convert Taiwan Traditional to general Traditional Chinese.
        """
        refs = self._get_dict_refs("tw2t")
        return refs.apply_segment_replace(input_text, self.segment_replace)

    def tw2tp(self, input_text: str) -> str:
        """
        Convert Taiwan Traditional to Traditional with phrase reversal.
        """
        refs = self._get_dict_refs("tw2tp")
        return refs.apply_segment_replace(input_text, self.segment_replace)

    def t2hk(self, input_text: str) -> str:
        """
        Convert Traditional Chinese to Hong Kong variant.
        """
        refs = self._get_dict_refs("t2hk")
        return refs.apply_segment_replace(input_text, self.segment_replace)

    def hk2t(self, input_text: str) -> str:
        """
        Convert Hong Kong Traditional to standard Traditional Chinese.
        """
        refs = self._get_dict_refs("hk2t")
        return refs.apply_segment_replace(input_text, self.segment_replace)

    def t2jp(self, input_text: str) -> str:
        """
        Convert Traditional Chinese to Japanese variants.
        """
        refs = self._get_dict_refs("t2jp")
        return refs.apply_segment_replace(input_text, self.segment_replace)

    def jp2t(self, input_text: str) -> str:
        """
        Convert Japanese Shinjitai (modern Kanji) to Traditional Chinese.
        """
        refs = self._get_dict_refs("jp2t")
        return refs.apply_segment_replace(input_text, self.segment_replace)

    def convert(self, input_text: str, punctuation: bool = False) -> str:
        """
        Automatically dispatch to the appropriate conversion method based on `self.config`.

        :param input_text: The string to convert
        :param punctuation: Whether to apply punctuation conversion
        :return: Converted string or error message
        """
        if not input_text:
            self._last_error = "Input text is empty"
            return ""

        config = self.config.lower()
        try:
            if config == "s2t":
                return self.s2t(input_text, punctuation)
            elif config == "s2tw":
                return self.s2tw(input_text, punctuation)
            elif config == "s2twp":
                return self.s2twp(input_text, punctuation)
            elif config == "s2hk":
                return self.s2hk(input_text, punctuation)
            elif config == "t2s":
                return self.t2s(input_text, punctuation)
            elif config == "t2tw":
                return self.t2tw(input_text)
            elif config == "t2twp":
                return self.t2twp(input_text)
            elif config == "t2hk":
                return self.t2hk(input_text)
            elif config == "tw2s":
                return self.tw2s(input_text, punctuation)
            elif config == "tw2sp":
                return self.tw2sp(input_text, punctuation)
            elif config == "tw2t":
                return self.tw2t(input_text)
            elif config == "tw2tp":
                return self.tw2tp(input_text)
            elif config == "hk2s":
                return self.hk2s(input_text, punctuation)
            elif config == "hk2t":
                return self.hk2t(input_text)
            elif config == "jp2t":
                return self.jp2t(input_text)
            elif config == "t2jp":
                return self.t2jp(input_text)
            else:
                self._last_error = f"Invalid config: {config}"
                return self._last_error
        except Exception as e:
            self._last_error = f"Conversion failed: {e}"
            return self._last_error

    def st(self, input_text: str) -> str:
        """
        Convert Simplified Chinese characters only (no phrases).
        """
        if not input_text:
            return input_text

        dict_data = [self.dictionary.st_characters]
        return self.convert_segment(input_text, dict_data, 1)

    def ts(self, input_text: str) -> str:
        """
        Convert Traditional Chinese characters only (no phrases).
        """
        if not input_text:
            return input_text

        dict_data = [self.dictionary.ts_characters]
        return self.convert_segment(input_text, dict_data, 1)

    def zho_check(self, input_text: str) -> int:
        """
        Heuristically determine whether input text is Simplified or Traditional Chinese.

        :param input_text: Input string
        :return: 0 = unknown, 1 = traditional, 2 = simplified
        """
        if not input_text:
            return 0

        stripped = STRIP_REGEX.sub("", input_text)
        strip_text = stripped[:100]

        if strip_text != self.ts(strip_text):
            return 1
        elif strip_text != self.st(strip_text):
            return 2
        else:
            return 0


def chunk_ranges(ranges: List[Tuple[int, int]], group_count: int) -> List[List[Tuple[int, int]]]:
    """
    Split a list of (start, end) index ranges into evenly sized chunks.

    This function divides the input list of ranges into approximately equal-sized sublists,
    useful for distributing work across multiple worker processes or threads.

    :param ranges: A list of (start, end) index tuples representing text segments.
    :param group_count: Number of groups to divide the ranges into (typically the number of worker processes).
    :return: A list of range groups, each being a list of (start, end) tuples.
    """
    chunk_size = (len(ranges) + group_count - 1) // group_count
    return [ranges[i:i + chunk_size] for i in range(0, len(ranges), chunk_size)]


def convert_range_group(args):
    """
    Convert a group of text segments using the provided conversion function.

    This function is designed for use with multiprocessing. It processes a group of
    (start, end) index ranges from the original input text, applies the dictionary-based
    segment conversion to each, and joins the results.

    :param args: A tuple containing:
        - text: The original input string.
        - group_ranges: A list of (start, end) index tuples for this group.
        - dictionaries: A list of (dictionary, max_length) tuples.
        - max_word_length: The maximum matching length used for dictionary lookup.
        - convert_segment_fn: A callable function to convert each segment.
    :return: A string representing the converted result for the group.
    """
    text, group_ranges, dictionaries, max_word_length, convert_segment_fn = args
    conv = convert_segment_fn  # local bind
    return ''.join(
        conv(text[start:end], dictionaries, max_word_length)
        for start, end in group_ranges
    )
