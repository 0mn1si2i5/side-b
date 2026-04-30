"""Integration tests for auth endpoints."""

import time

from fastapi.testclient import TestClient

from tests.conftest import auth_headers, register_user


def test_register_valid_data(client: TestClient):
    resp = client.post("/api/auth/register", json={
        "username": f"u_{int(time.time())}",
        "password": "ValidPass123!",
        "displayName": "New User",
        "avatarName": "avatar_1",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert "token" in data
    assert data["user"]["username"].startswith("u_")


def test_register_duplicate_username(client: TestClient):
    suffix = int(time.time() * 1000)
    body = {
        "username": f"dup_{suffix}",
        "password": "ValidPass123!",
        "displayName": "Dup User",
        "avatarName": "avatar_1",
    }
    resp1 = client.post("/api/auth/register", json=body)
    assert resp1.status_code == 200

    resp2 = client.post("/api/auth/register", json=body)
    assert resp2.status_code == 400


def test_register_short_password(client: TestClient):
    resp = client.post("/api/auth/register", json={
        "username": f"sp_{int(time.time())}",
        "password": "abc",
        "displayName": "Short PW",
        "avatarName": "avatar_1",
    })
    assert resp.status_code == 422


def test_login_valid_credentials(client: TestClient):
    result = register_user(client)
    login_body = {
        "username": result["user"]["username"],
        "password": "TestPass123!",
    }
    resp = client.post("/api/auth/login", json=login_body)
    assert resp.status_code == 200
    data = resp.json()
    assert "token" in data
    assert data["user"]["username"] == result["user"]["username"]


def test_login_wrong_password(client: TestClient):
    result = register_user(client)
    login_body = {
        "username": result["user"]["username"],
        "password": "WrongPassword999!",
    }
    resp = client.post("/api/auth/login", json=login_body)
    assert resp.status_code == 401


def test_password_change_correct_old(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])

    resp = client.put("/api/auth/password", json={
        "old_password": "TestPass123!",
        "new_password": "NewPass456!",
    }, headers=headers)
    assert resp.status_code == 200

    login_resp = client.post("/api/auth/login", json={
        "username": result["user"]["username"],
        "password": "NewPass456!",
    })
    assert login_resp.status_code == 200


def test_password_change_wrong_old(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])

    resp = client.put("/api/auth/password", json={
        "old_password": "WrongOldPass!",
        "new_password": "NewPass456!",
    }, headers=headers)
    assert resp.status_code == 401


def test_logout_revokes_token(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])

    resp = client.post("/api/auth/logout", headers=headers)
    assert resp.status_code == 200

    me_resp = client.get("/api/auth/me", headers=headers)
    assert me_resp.status_code == 401


def test_update_profile_display_name_avatar_and_platform(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])

    resp = client.put("/api/auth/me", json={
        "displayName": "Renamed User",
        "avatarName": "avatar_15",
        "preferredPlatform": "spotify",
    }, headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data["displayName"] == "Renamed User"
    assert data["avatarName"] == "avatar_15"
    assert data["preferredPlatform"] == "spotify"

    me_resp = client.get("/api/auth/me", headers=headers)
    assert me_resp.status_code == 200
    me = me_resp.json()
    assert me["displayName"] == "Renamed User"
    assert me["avatarName"] == "avatar_15"


def test_update_profile_rejects_invalid_avatar(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])

    resp = client.put("/api/auth/me", json={
        "avatarName": "avatar_999",
    }, headers=headers)
    assert resp.status_code == 400


def test_update_profile_preserves_platform_when_field_is_omitted(client: TestClient):
    result = register_user(client)
    headers = auth_headers(result["token"])

    platform_resp = client.put("/api/auth/me", json={
        "preferredPlatform": "apple_music",
    }, headers=headers)
    assert platform_resp.status_code == 200
    assert platform_resp.json()["preferredPlatform"] == "apple_music"

    name_resp = client.put("/api/auth/me", json={
        "displayName": "Name Only",
    }, headers=headers)
    assert name_resp.status_code == 200
    assert name_resp.json()["displayName"] == "Name Only"
    assert name_resp.json()["preferredPlatform"] == "apple_music"
