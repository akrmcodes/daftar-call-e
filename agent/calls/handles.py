"""Process-local Daftar confirm handles. Never log the token.

Cloud Run min-instances 0 drops this store on scale-to-zero. Durable SoT is
Drift on the device after 1.2 persists runId. Re-plan replaces the token.
"""

from __future__ import annotations

import secrets
from threading import Lock


class ConfirmHandleStore:
    def put(self, batch_id: str, contact_id: str, token: str) -> None:
        raise NotImplementedError

    def get(self, batch_id: str, contact_id: str) -> str | None:
        raise NotImplementedError

    def delete(self, batch_id: str, contact_id: str) -> None:
        raise NotImplementedError


class InMemoryConfirmHandleStore(ConfirmHandleStore):
    def __init__(self) -> None:
        self._lock = Lock()
        self._tokens: dict[tuple[str, str], str] = {}

    def put(self, batch_id: str, contact_id: str, token: str) -> None:
        with self._lock:
            self._tokens[(batch_id, contact_id)] = token

    def get(self, batch_id: str, contact_id: str) -> str | None:
        with self._lock:
            return self._tokens.get((batch_id, contact_id))

    def delete(self, batch_id: str, contact_id: str) -> None:
        with self._lock:
            self._tokens.pop((batch_id, contact_id), None)


def new_confirm_handle() -> str:
    return secrets.token_urlsafe(32)
