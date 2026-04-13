import re
from urllib import request


def resolve_netease_link(raw_link: str) -> str:
    normalized = raw_link.strip()
    if "163cn.tv" not in normalized:
        return normalized

    req = request.Request(normalized, method="GET")
    with request.urlopen(req, timeout=10) as response:
        return response.geturl()


def parse_netease_track_id(raw_link: str) -> str | None:
    resolved_link = resolve_netease_link(raw_link)

    query_id_match = re.search(r"[?&]id=(\d+)", resolved_link)
    if query_id_match:
        return query_id_match.group(1)

    path_id_match = re.search(r"/song/(\d+)", resolved_link)
    if path_id_match:
        return path_id_match.group(1)

    return None
