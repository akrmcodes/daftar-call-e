"""Developer API create/get wrapper. Lazy import. Never wait. Never log the key."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Protocol

from calls.schemas import RECIPIENT_RESULT_SCHEMA, TASK_RESULT_SCHEMA

PROD_BASE = "https://api.heycall-e.com"
DEFAULT_KEY_FILE = "/calle-secrets/calle-api-key"
CREATE_TIMEOUT_SEC = 30.0
GET_TIMEOUT_SEC = 30.0


class CallNotFoundError(Exception):
    """CALL-E returned 404 / not_found for the run id."""


class UpstreamAuthError(Exception):
    """CALL-E rejected the API key (401/403)."""


class UpstreamUnavailableError(Exception):
    """CALL-E timeout or connection failure before a response."""


class CallCreator(Protocol):
    def create(
        self,
        *,
        api_key_file: str,
        task: str,
        phone: str,
        region: str,
        locale: str,
        metadata: dict[str, str],
        idempotency_key: str,
    ) -> str:
        """Return CALL-E call.id. Must not poll."""
        ...

    def get(self, *, api_key_file: str, run_id: str) -> dict[str, Any]:
        """Return CALL-E call dict. Must not poll."""
        ...


def load_api_key(api_key_file: str) -> str:
    path = Path(api_key_file.strip() or DEFAULT_KEY_FILE)
    return path.read_text(encoding="utf-8").strip()


def _reraise_get_error(exc: Exception) -> None:
    from calle.errors import (
        CalleAPIError,
        CalleAuthenticationError,
        CalleConnectionError,
        CalleTimeoutError,
    )

    if isinstance(exc, CalleAuthenticationError):
        raise UpstreamAuthError() from exc
    if isinstance(exc, CalleAPIError):
        if exc.status_code == 404 or exc.code == "not_found":
            raise CallNotFoundError() from exc
        if exc.status_code in {401, 403}:
            raise UpstreamAuthError() from exc
    if isinstance(exc, (CalleTimeoutError, CalleConnectionError)):
        raise UpstreamUnavailableError() from exc
    raise exc


class StdlibCallCreator:
    def create(
        self,
        *,
        api_key_file: str,
        task: str,
        phone: str,
        region: str,
        locale: str,
        metadata: dict[str, str],
        idempotency_key: str,
    ) -> str:
        key = load_api_key(api_key_file)
        try:
            from calle import CalleClient

            client = CalleClient(
                api_key=key,
                base_url=PROD_BASE,
                timeout=CREATE_TIMEOUT_SEC,
            )
            try:
                call: dict[str, Any] = client.calls.create(
                    task=task,
                    recipients=[
                        {"phones": [phone], "region": region, "locale": locale}
                    ],
                    result_schema=TASK_RESULT_SCHEMA,
                    recipient_result_schema=RECIPIENT_RESULT_SCHEMA,
                    metadata=metadata,
                    idempotency_key=idempotency_key,
                )
            finally:
                client.close()
        finally:
            del key
        run_id = call.get("id")
        if not isinstance(run_id, str) or not run_id.strip():
            raise RuntimeError("missing_call_id")
        return run_id.strip()

    def get(self, *, api_key_file: str, run_id: str) -> dict[str, Any]:
        key = load_api_key(api_key_file)
        try:
            from calle import CalleClient

            client = CalleClient(
                api_key=key,
                base_url=PROD_BASE,
                timeout=GET_TIMEOUT_SEC,
            )
            try:
                call: dict[str, Any] = client.calls.get(run_id)
            except Exception as exc:
                _reraise_get_error(exc)
            finally:
                client.close()
        finally:
            del key
        if not isinstance(call, dict):
            raise UpstreamUnavailableError()
        return call
