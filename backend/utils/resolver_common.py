import os
import re
import sys
import time

BACKEND_DIR = os.path.dirname(os.path.dirname(__file__))
VENDOR_PATH = os.path.join(BACKEND_DIR, "vendor")
if os.path.isdir(VENDOR_PATH) and VENDOR_PATH not in sys.path:
    sys.path.insert(0, VENDOR_PATH)

try:
    from opencc_purepy import OpenCC
except ImportError:
    OpenCC = None


CACHE_TTL_SECONDS = 15 * 60
CACHE_MISS = object()
TITLE_VERSION_KEYWORDS = (
    "live",
    "remix",
    "remaster",
    "remastered",
    "version",
    "edit",
    "cover",
    "demo",
    "mix",
    "acoustic",
    "karaoke",
    "instrumental",
    "commentary",
    "radio edit",
    "sped up",
    "slowed",
)
COMPILATION_KEYWORDS = (
    "various artists",
    "群星",
    "合辑",
    "精选",
    "hits",
    "best of",
    "workout",
    "karaoke",
)
T2S_CONVERTER = OpenCC("t2s") if OpenCC else None
S2T_CONVERTER = OpenCC("s2t") if OpenCC else None


def normalize_preferred_market(preferred_market: str | None) -> str | None:
    if not preferred_market:
        return None

    normalized = preferred_market.strip().lower()
    if re.fullmatch(r"[a-z]{2}", normalized):
        return normalized

    return None


def convert_chinese_text(raw_value: str, converter) -> str:
    if not raw_value or converter is None:
        return raw_value

    return converter.convert(raw_value)


def text_variants(raw_value: str | None) -> list[str]:
    if not raw_value:
        return []

    variants = [
        raw_value,
        convert_chinese_text(raw_value, T2S_CONVERTER),
        convert_chinese_text(raw_value, S2T_CONVERTER),
    ]

    deduplicated: list[str] = []
    seen: set[str] = set()
    for value in variants:
        cleaned = value.strip()
        if not cleaned or cleaned in seen:
            continue
        seen.add(cleaned)
        deduplicated.append(cleaned)

    return deduplicated


def normalize_text(raw_value: str | None) -> str:
    if not raw_value:
        return ""

    normalized = convert_chinese_text(raw_value, T2S_CONVERTER).casefold()
    normalized = re.sub(r"\([^)]*\)", " ", normalized)
    normalized = re.sub(r"\[[^\]]*\]", " ", normalized)
    normalized = re.sub(r"[^a-z0-9\u4e00-\u9fff]+", " ", normalized)
    return re.sub(r"\s+", " ", normalized).strip()


def normalize_text_preserving_versions(raw_value: str | None) -> str:
    if not raw_value:
        return ""

    normalized = convert_chinese_text(raw_value, T2S_CONVERTER).casefold()
    normalized = re.sub(r"[^a-z0-9\u4e00-\u9fff]+", " ", normalized)
    return re.sub(r"\s+", " ", normalized).strip()


def base_title_variants(title: str) -> list[str]:
    variants = [title.strip()]
    stripped_title = re.sub(r"\s*[\(\[].*?[\)\]]\s*", " ", title).strip()
    if stripped_title:
        variants.append(stripped_title)

    deduplicated: list[str] = []
    seen: set[str] = set()
    for value in variants:
        normalized = normalize_text(value)
        if normalized and normalized not in seen:
            seen.add(normalized)
            deduplicated.append(value)

    return deduplicated


def contains_keyword(value: str, keywords: tuple[str, ...]) -> bool:
    return any(keyword in value for keyword in keywords)


def cache_key_for_url(source_url: str, preferred_market: str | None) -> tuple[str, str | None]:
    return (source_url, normalize_preferred_market(preferred_market))


def read_cached_value(cache_store: dict, cache_key: tuple[str, str | None]):
    cached_entry = cache_store.get(cache_key)
    if not cached_entry:
        return CACHE_MISS

    cached_at, cached_value = cached_entry
    if time.time() - cached_at > CACHE_TTL_SECONDS:
        cache_store.pop(cache_key, None)
        return CACHE_MISS

    return cached_value


def write_cached_value(cache_store: dict, cache_key: tuple[str, str | None], cached_value) -> None:
    cache_store[cache_key] = (time.time(), cached_value)
