"""ADC Chirp 3 HD unary synthesize. Google client is imported lazily."""

from __future__ import annotations

from typing import Protocol

from tts.voices import SPEAKING_RATE


class TtsClient(Protocol):
    def synthesize(
        self,
        *,
        text: str,
        language_code: str,
        voice_name: str,
        speaking_rate: float = SPEAKING_RATE,
    ) -> bytes:
        """Return MP3 bytes. Must not log [text]."""
        ...


class GoogleChirpTtsClient:
    """Unary ``synthesize_speech`` via Application Default Credentials."""

    def __init__(self) -> None:
        self._inner: object | None = None

    def synthesize(
        self,
        *,
        text: str,
        language_code: str,
        voice_name: str,
        speaking_rate: float = SPEAKING_RATE,
    ) -> bytes:
        from google.cloud import texttospeech

        client = self._inner
        if client is None:
            client = texttospeech.TextToSpeechClient()
            self._inner = client
        response = client.synthesize_speech(
            input=texttospeech.SynthesisInput(text=text),
            voice=texttospeech.VoiceSelectionParams(
                language_code=language_code,
                name=voice_name,
            ),
            audio_config=texttospeech.AudioConfig(
                audio_encoding=texttospeech.AudioEncoding.MP3,
                speaking_rate=speaking_rate,
            ),
        )
        audio = response.audio_content
        if not audio:
            raise RuntimeError("empty_audio")
        return bytes(audio)
