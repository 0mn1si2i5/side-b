import json
import sys

from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

sys.path.insert(0, "backend")

from platform_clients import netease_client


class _Response:
    def __init__(self, body: bytes) -> None:
        self.body = body

    def __enter__(self):
        return self

    def __exit__(self, *_args):
        return None

    def read(self) -> bytes:
        return self.body


def _encrypt_eapi_response(payload: dict) -> bytes:
    plaintext = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    padding_length = 16 - (len(plaintext) % 16)
    padded = plaintext + bytes([padding_length]) * padding_length
    encryptor = Cipher(algorithms.AES(netease_client.EAPI_AES_KEY), modes.ECB()).encryptor()
    return (encryptor.update(padded) + encryptor.finalize()).hex().encode("ascii")


def test_public_search_decodes_encrypted_hex_response(monkeypatch):
    payload = {"code": 200, "result": {"songs": [{"id": 123, "name": "New Normal"}]}}
    monkeypatch.setattr(
        netease_client.request,
        "urlopen",
        lambda *_args, **_kwargs: _Response(_encrypt_eapi_response(payload)),
    )

    assert netease_client.search_public_tracks("New Normal") == payload["result"]["songs"]


def test_public_search_decodes_nested_encrypted_result(monkeypatch):
    result = {"songs": [{"id": 123, "name": "New Normal"}]}
    outer_payload = {"code": 200, "result": _encrypt_eapi_response(result).decode("ascii")}
    monkeypatch.setattr(
        netease_client.request,
        "urlopen",
        lambda *_args, **_kwargs: _Response(json.dumps(outer_payload).encode("utf-8")),
    )

    assert netease_client.search_public_tracks("New Normal") == result["songs"]
