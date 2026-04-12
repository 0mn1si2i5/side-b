from pathlib import Path
from threading import Lock
from typing import Dict, Tuple


class DictionaryMaxlength:
    """
    A container for OpenCC-compatible dictionaries with each represented
    as a (dict, max_length) tuple to optimize the longest match lookup.
    """
    _provider = None
    _provider_lock = Lock()

    def __init__(self):
        """
        Initialize all supported dictionary attributes to empty dicts with max_length = 0.
        """
        self.st_characters: Tuple[Dict[str, str], int] = ({}, 0)
        self.st_phrases: Tuple[Dict[str, str], int] = ({}, 0)
        self.ts_characters: Tuple[Dict[str, str], int] = ({}, 0)
        self.ts_phrases: Tuple[Dict[str, str], int] = ({}, 0)
        self.tw_phrases: Tuple[Dict[str, str], int] = ({}, 0)
        self.tw_phrases_rev: Tuple[Dict[str, str], int] = ({}, 0)
        self.tw_variants: Tuple[Dict[str, str], int] = ({}, 0)
        self.tw_variants_rev: Tuple[Dict[str, str], int] = ({}, 0)
        self.tw_variants_rev_phrases: Tuple[Dict[str, str], int] = ({}, 0)
        self.hk_variants: Tuple[Dict[str, str], int] = ({}, 0)
        self.hk_variants_rev: Tuple[Dict[str, str], int] = ({}, 0)
        self.hk_variants_rev_phrases: Tuple[Dict[str, str], int] = ({}, 0)
        self.jps_characters: Tuple[Dict[str, str], int] = ({}, 0)
        self.jps_phrases: Tuple[Dict[str, str], int] = ({}, 0)
        self.jp_variants: Tuple[Dict[str, str], int] = ({}, 0)
        self.jp_variants_rev: Tuple[Dict[str, str], int] = ({}, 0)

    def __repr__(self):
        count = sum(bool(v[0]) for v in self.__dict__.values())
        return "<DictionaryMaxlength with {} loaded dicts>".format(count)

    @classmethod
    def get_provider(cls):
        """
        Return a shared dictionary provider loaded from precompiled JSON.
        :return: DictionaryMaxlength instance
        """
        if cls._provider is None:
            with cls._provider_lock:
                if cls._provider is None:
                    cls._provider = cls.from_json()
        return cls._provider

    @classmethod
    def new(cls):
        """
        Backward-compatible alias for the shared dictionary provider.
        :return: DictionaryMaxlength instance
        """
        return cls.get_provider()

    @classmethod
    def from_json(cls):
        """
        Load dictionary data from a JSON file where each field is a list [dict, int].
        :return: Populated DictionaryMaxlength instance
        """
        import json
        path = Path(__file__).parent / "dicts" / "dictionary_maxlength.json"
        with open(path, "r", encoding="utf-8") as f:
            raw_data = json.load(f)

        instance = cls()

        for key, value in raw_data.items():
            if isinstance(value, list) and len(value) == 2 and isinstance(value[0], dict) and isinstance(value[1], int):
                setattr(instance, key, (value[0], value[1]))
            else:
                raise ValueError("Invalid dictionary format for key: {}".format(key))

        return instance

    @classmethod
    def from_dicts(cls):
        """
        Load dictionaries directly from text files in the 'dicts' folder.
        Each file should contain tab-separated mappings.
        :return: Populated DictionaryMaxlength instance
        """
        instance = cls()
        paths = {
            'st_characters': "STCharacters.txt",
            'st_phrases': "STPhrases.txt",
            'ts_characters': "TSCharacters.txt",
            'ts_phrases': "TSPhrases.txt",
            'tw_phrases': "TWPhrases.txt",
            'tw_phrases_rev': "TWPhrasesRev.txt",
            'tw_variants': "TWVariants.txt",
            'tw_variants_rev': "TWVariantsRev.txt",
            'tw_variants_rev_phrases': "TWVariantsRevPhrases.txt",
            'hk_variants': "HKVariants.txt",
            'hk_variants_rev': "HKVariantsRev.txt",
            'hk_variants_rev_phrases': "HKVariantsRevPhrases.txt",
            'jps_characters': "JPShinjitaiCharacters.txt",
            'jps_phrases': "JPShinjitaiPhrases.txt",
            'jp_variants': "JPVariants.txt",
            'jp_variants_rev': "JPVariantsRev.txt",
        }

        base = Path(__file__).parent / "dicts"
        for attr, filename in paths.items():
            content = (base / filename).read_text(encoding="utf-8")
            setattr(instance, attr, cls.load_dictionary_maxlength(content))

        return instance

    @staticmethod
    def load_dictionary_maxlength(content: str) -> Tuple[Dict[str, str], int]:
        """
        Load a dictionary from plain text and determine the max phrase length.

        :param content: Raw dictionary text (one mapping per line)
        :return: Tuple of dict and max key length
        """
        dictionary = {}
        max_length = 1

        for line in content.strip().splitlines():
            stripped_line = line.strip()
            if not stripped_line or stripped_line.startswith("#"):
                continue

            parts = stripped_line.split()
            if len(parts) >= 2:
                phrase, translation = parts[0], parts[1]
                dictionary[phrase] = translation
                max_length = max(max_length, len(phrase))
            else:
                import warnings
                warnings.warn("Ignoring malformed dictionary line: {}".format(line))

        return dictionary, max_length

    def serialize_to_json(self, path: str):
        """
        Serialize the current dictionary data to a JSON file.

        :param path: Output file path
        """
        import json
        with open(path, "w", encoding="utf-8") as f:
            json.dump(self.__dict__, f, ensure_ascii=False, indent=2)
