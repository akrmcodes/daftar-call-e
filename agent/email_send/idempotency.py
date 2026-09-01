"""Process-local send-batch idempotency (batchId + to).

Cloud Run min-instances 0 drops this store on scale-to-zero. Durable source of
truth is Drift in §4.8. Unit tests inject a fake store.
"""

from __future__ import annotations

import threading
from typing import Protocol


class EmailIdempotencyStore(Protocol):
    def get(self, batch_id: str, to_address: str) -> str | None:
        """Return stored ``smtpMessageId`` if this pair already sent."""

    def put(self, batch_id: str, to_address: str, smtp_message_id: str) -> None:
        """Remember a successful send for this pair."""


class InMemoryEmailIdempotencyStore:
    """Thread-safe in-process map keyed by ``(batchId, to.lower())``."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._data: dict[tuple[str, str], str] = {}

    def _key(self, batch_id: str, to_address: str) -> tuple[str, str]:
        return (batch_id, to_address.strip().lower())

    def get(self, batch_id: str, to_address: str) -> str | None:
        with self._lock:
            return self._data.get(self._key(batch_id, to_address))

    def put(self, batch_id: str, to_address: str, smtp_message_id: str) -> None:
        with self._lock:
            self._data[self._key(batch_id, to_address)] = smtp_message_id
