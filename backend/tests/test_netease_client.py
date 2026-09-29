import json
import sys
from urllib import parse

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


def test_public_search_uses_public_eapi_cloudsearch_transport(monkeypatch):
    captured = {}
    payload = {"code": 200, "result": {"songs": [{"id": 1409136858, "name": "New Normal"}]}}

    def fake_urlopen(req, **_kwargs):
        captured["url"] = req.full_url
        captured["body"] = parse.parse_qs(req.data.decode("ascii"))["params"][0]
        decrypted = Cipher(algorithms.AES(netease_client.EAPI_AES_KEY), modes.ECB()).decryptor()
        padded = decrypted.update(bytes.fromhex(captured["body"])) + decrypted.finalize()
        padding_length = padded[-1]
        request_text = padded[:-padding_length].decode("utf-8")
        assert request_text.startswith("/api/cloudsearch/pc-36cd479b6b5-")
        assert '"s":"New Normal"' in request_text
        assert '"total":true' in request_text
        assert '"e_r":false' in request_text
        return _Response(json.dumps(payload).encode("utf-8"))

    monkeypatch.setattr(netease_client.request, "urlopen", fake_urlopen)

    assert netease_client.search_public_tracks("New Normal") == payload["result"]["songs"]
    assert captured["url"] == "https://interface.music.163.com/eapi/cloudsearch/pc"


def test_public_search_decodes_nested_encrypted_result(monkeypatch):
    result = {"songs": [{"id": 123, "name": "New Normal"}]}
    outer_payload = {
        "code": 200,
        "abroad": True,
        "result": _encrypt_eapi_response(result).decode("ascii"),
    }
    monkeypatch.setattr(
        netease_client.request,
        "urlopen",
        lambda *_args, **_kwargs: _Response(json.dumps(outer_payload).encode("utf-8")),
    )

    assert netease_client.search_public_tracks("New Normal") == result["songs"]
