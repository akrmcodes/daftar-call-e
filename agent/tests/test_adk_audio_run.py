"""Stage 5.1: /run JSON accepts inline WAV; no live Vertex."""

from __future__ import annotations

import base64
import copy
import struct
import uuid
from pathlib import Path
from typing import Any

import yaml
from jsonschema import Draft202012Validator

from tests.test_proposal_tools import _inline_refs

OPENAPI_PATH = Path(__file__).resolve().parents[1] / "openapi.yaml"


def _tiny_wav() -> bytes:
    """44-byte WAV header + one silent PCM16 sample (16 kHz mono)."""
    data = b"\x00\x00"
    header = struct.pack(
        "<4sI4s4sIHHIIHH4sI",
        b"RIFF",
        36 + len(data),
        b"WAVE",
        b"fmt ",
        16,
        1,
        1,
        16000,
        32000,
        2,
        16,
        b"data",
        len(data),
    )
    return header + data


def _schemas() -> dict[str, Any]:
    with OPENAPI_PATH.open(encoding="utf-8") as f:
        return yaml.safe_load(f)["components"]["schemas"]


def _validate(schema_name: str, payload: dict[str, Any]) -> None:
    schemas = _schemas()
    schema = _inline_refs(copy.deepcopy(schemas[schema_name]), schemas)
    Draft202012Validator(schema).validate(payload)


def test_adk_content_part_accepts_text_or_inline_data() -> None:
    _validate("AdkContentPart", {"text": "__voice__"})
    _validate(
        "AdkContentPart",
        {
            "inlineData": {
                "mimeType": "audio/wav",
                "data": base64.b64encode(_tiny_wav()).decode("ascii"),
            }
        },
    )


def test_adk_run_request_voice_shape_uses_inline_audio_ref() -> None:
    wav_b64 = base64.b64encode(_tiny_wav()).decode("ascii")
    payload = {
        "appName": "closing_agent",
        "userId": "gid-1",
        "sessionId": str(uuid.uuid4()),
        "stateDelta": {
            "daftarContext": {
                "correlationId": str(uuid.uuid4()),
                "locale": "ar",
                "merchantLocalDay": "2026-08-21",
                "ledgers": [
                    {
                        "id": "11111111-1111-4111-8111-111111111111",
                        "name": "Customers",
                    }
                ],
                "voiceHints": [],
                "isMultiCurrencyEnabled": False,
                "defaultCurrency": "YER",
                "goalText": "__voice__",
                "audioRef": "inline:audio/wav",
            }
        },
        "newMessage": {
            "role": "user",
            "parts": [
                {"text": "__voice__"},
                {
                    "inlineData": {
                        "mimeType": "audio/wav",
                        "data": wav_b64,
                    }
                },
            ],
        },
    }
    _validate("AdkRunRequest", payload)
    context = payload["stateDelta"]["daftarContext"]
    assert context["audioRef"] == "inline:audio/wav"
    assert wav_b64 not in context["audioRef"]
    assert "data" not in context
