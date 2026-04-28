import asyncio

from platform_clients import qq_music_client


def test_async_client_call_runs_inside_existing_event_loop(monkeypatch):
    async def fake_fetch(track_mid: str) -> dict:
        await asyncio.sleep(0)
        return {"mid": track_mid, "title": "Song"}

    monkeypatch.setattr(qq_music_client, "_fetch_track_detail_async", fake_fetch)

    async def run_in_event_loop() -> dict:
        return qq_music_client.fetch_track_detail("001Zw5zl0kk7cQ")

    track_payload = asyncio.run(run_in_event_loop())

    assert track_payload["mid"] == "001Zw5zl0kk7cQ"
