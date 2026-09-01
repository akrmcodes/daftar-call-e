"""Chirp 3 HD POST /v1/tts — fake client, no live GCP."""

from __future__ import annotations

import base64
import json
from dataclasses import dataclass, field
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from tts.router import get_tts_client, router
from tts.voices import (
    MAX_TTS_CHARS,
    MIME_MP3,
    SPEAKING_RATE,
    VOICE_AR,
    VOICE_EN,
    voice_for_locale,
)

SECRET_UTTERANCE = "MERCHANT-TEXT-MUST-NOT-APPEAR-IN-LOGS-XYZ"
FAKE_MP3 = b"ID3FAKE-MP3-BYTES"


@dataclass
class FakeTtsClient:
    calls: list[dict[str, Any]] = field(default_factory=list)
    audio: bytes = FAKE_MP3
    fail: bool = False

    def synthesize(
        self,
        *,
        text: str,
        language_code: str,
        voice_name: str,
        speaking_rate: float = SPEAKING_RATE,
    ) -> bytes:
        self.calls.append(
            {
                "text": text,
                "language_code": language_code,
                "voice_name": voice_name,
                "speaking_rate": speaking_rate,
            }
        )
        if self.fail:
            raise RuntimeError("gcp_down")
        return self.audio


def _app(fake: FakeTtsClient) -> TestClient:
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_tts_client] = lambda: fake
    return TestClient(app)


def test_voice_for_locale_enceladus() -> None:
    language_ar, voice_ar = voice_for_locale("ar")
    language_en, voice_en = voice_for_locale("en")
    assert language_ar == "ar-XA"
    assert voice_ar == VOICE_AR == "ar-XA-Chirp3-HD-Enceladus"
    assert language_en == "en-US"
    assert voice_en == VOICE_EN == "en-US-Chirp3-HD-Enceladus"


@pytest.mark.parametrize(
    ("locale", "language_code", "voice_name"),
    [
        ("ar", "ar-XA", VOICE_AR),
        ("en", "en-US", VOICE_EN),
    ],
)
def test_locale_selects_enceladus_voice(
    locale: str,
    language_code: str,
    voice_name: str,
    capsys: pytest.CaptureFixture[str],
) -> None:
    fake = FakeTtsClient()
    client = _app(fake)
    response = client.post(
        "/v1/tts",
        json={"text": "Hello world.", "locale": locale},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["mimeType"] == MIME_MP3
    assert base64.b64decode(body["audioBase64"]) == FAKE_MP3
    assert fake.calls[0]["language_code"] == language_code
    assert fake.calls[0]["voice_name"] == voice_name
    assert fake.calls[0]["speaking_rate"] == SPEAKING_RATE
    log = capsys.readouterr().out
    entry = json.loads(log.strip().splitlines()[-1])
    assert entry["event"] == "daftar.agent.tts"
    assert entry["voice"] == voice_name
    assert entry["locale"] == locale
    assert entry["chars"] == len("Hello world.")
    assert "latency_ms" in entry
    assert "Hello world." not in log


def test_empty_text_is_400() -> None:
    fake = FakeTtsClient()
    client = _app(fake)
    response = client.post("/v1/tts", json={"text": "   ", "locale": "ar"})
    assert response.status_code == 400
    assert response.json()["detail"] == "empty_text"
    assert fake.calls == []


def test_missing_text_is_422() -> None:
    fake = FakeTtsClient()
    client = _app(fake)
    response = client.post("/v1/tts", json={"locale": "ar"})
    assert response.status_code == 422
    assert fake.calls == []


def test_cap_is_400() -> None:
    fake = FakeTtsClient()
    client = _app(fake)
    response = client.post(
        "/v1/tts",
        json={"text": "x" * (MAX_TTS_CHARS + 1), "locale": "en"},
    )
    assert response.status_code == 400
    assert response.json()["detail"] == "text_too_long"
    assert fake.calls == []


def test_invalid_locale_is_422() -> None:
    fake = FakeTtsClient()
    client = _app(fake)
    response = client.post("/v1/tts", json={"text": "hi", "locale": "fr"})
    assert response.status_code == 422
    assert fake.calls == []


def test_gcp_failure_is_502_and_does_not_log_utterance(
    capsys: pytest.CaptureFixture[str],
) -> None:
    fake = FakeTtsClient(fail=True)
    client = _app(fake)
    response = client.post(
        "/v1/tts",
        json={"text": SECRET_UTTERANCE, "locale": "ar"},
    )
    assert response.status_code == 502
    assert response.json()["detail"] == "tts_unavailable"
    log = capsys.readouterr().out
    assert SECRET_UTTERANCE not in log
    entry = json.loads(log.strip().splitlines()[-1])
    assert entry["event"] == "daftar.agent.tts"
    assert entry["severity"] == "ERROR"
    assert entry["voice"] == VOICE_AR
    assert entry["chars"] == len(SECRET_UTTERANCE)


def test_success_log_omits_merchant_text(capsys: pytest.CaptureFixture[str]) -> None:
    fake = FakeTtsClient()
    client = _app(fake)
    response = client.post(
        "/v1/tts",
        json={"text": SECRET_UTTERANCE, "locale": "en"},
    )
    assert response.status_code == 200
    log = capsys.readouterr().out
    assert SECRET_UTTERANCE not in log
    assert "audioBase64" not in log
