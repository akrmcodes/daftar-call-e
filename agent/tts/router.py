"""POST /v1/tts — Chirp 3 HD Enceladus MP3. Auth is Cloud Run IAM + Appendix J."""

from __future__ import annotations

import asyncio
import base64
import time
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, ConfigDict, Field

from closing_agent.observability import emit_structured
from tts.client import GoogleChirpTtsClient, TtsClient
from tts.voices import (
    MAX_TTS_CHARS,
    MIME_MP3,
    SPEAKING_RATE,
    Locale,
    voice_for_locale,
)

router = APIRouter(tags=["tts"])

_default_client = GoogleChirpTtsClient()


def get_tts_client() -> TtsClient:
    return _default_client


class TtsRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    text: str
    locale: Locale


class TtsResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    mimeType: Literal["audio/mpeg"] = MIME_MP3
    audioBase64: str = Field(min_length=1)


def _emit_tts(
    *,
    voice: str,
    locale: str,
    chars: int,
    latency_ms: int,
    severity: str = "INFO",
    message: str = "",
) -> None:
    emit_structured(
        "daftar.agent.tts",
        severity=severity,
        message=message or f"tts voice={voice} chars={chars} latency_ms={latency_ms}",
        voice=voice,
        locale=locale,
        chars=chars,
        latency_ms=latency_ms,
    )


@router.post("/v1/tts", response_model=TtsResponse)
async def synthesize_tts(
    body: TtsRequest,
    client: TtsClient = Depends(get_tts_client),
) -> TtsResponse:
    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=400, detail="empty_text")
    if len(text) > MAX_TTS_CHARS:
        raise HTTPException(status_code=400, detail="text_too_long")

    language_code, voice_name = voice_for_locale(body.locale)
    started = time.perf_counter()
    try:
        audio = await asyncio.to_thread(
            client.synthesize,
            text=text,
            language_code=language_code,
            voice_name=voice_name,
            speaking_rate=SPEAKING_RATE,
        )
    except Exception:
        latency_ms = int((time.perf_counter() - started) * 1000)
        _emit_tts(
            voice=voice_name,
            locale=body.locale,
            chars=len(text),
            latency_ms=latency_ms,
            severity="ERROR",
            message="tts_unavailable",
        )
        raise HTTPException(status_code=502, detail="tts_unavailable") from None

    if not audio:
        latency_ms = int((time.perf_counter() - started) * 1000)
        _emit_tts(
            voice=voice_name,
            locale=body.locale,
            chars=len(text),
            latency_ms=latency_ms,
            severity="ERROR",
            message="tts_empty_audio",
        )
        raise HTTPException(status_code=502, detail="tts_unavailable")

    latency_ms = int((time.perf_counter() - started) * 1000)
    _emit_tts(
        voice=voice_name,
        locale=body.locale,
        chars=len(text),
        latency_ms=latency_ms,
    )
    return TtsResponse(
        mimeType=MIME_MP3,
        audioBase64=base64.b64encode(audio).decode("ascii"),
    )
