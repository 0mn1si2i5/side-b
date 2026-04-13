#!/usr/bin/env python3
import os
from http.server import HTTPServer

from routes.resolve_route import ResolveRouteHandler, load_dotenv


def main() -> None:
    load_dotenv()
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8787"))
    server = HTTPServer((host, port), ResolveRouteHandler)
    print(f"Spotify resolver server listening on http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
