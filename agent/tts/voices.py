"""Locked Chirp 3 HD Enceladus ids. Same speaker across ar-XA and en-US."""

from __future__ import annotations

from typing import Literal

Locale = Literal["ar", "en"]

MAX_TTS_CHARS = 2000
SPEAKING_RATE = 0.95
MIME_MP3 = "audio/mpeg"

VOICE_AR = "ar-XA-Chirp3-HD-Enceladus"
VOICE_EN = "en-US-Chirp3-HD-Enceladus"
LANGUAGE_AR = "ar-XA"
LANGUAGE_EN = "en-US"


def normalize_locale(raw: str) -> Locale:
    return "en" if raw.strip().lower().startswith("en") else "ar"


def voice_for_locale(locale: Locale) -> tuple[str, str]:
    """Return ``(language_code, voice_name)`` for [locale]."""
    if locale == "en":
        return LANGUAGE_EN, VOICE_EN
    return LANGUAGE_AR, VOICE_AR
