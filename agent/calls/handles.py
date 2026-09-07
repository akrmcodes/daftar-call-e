"""Process-local Daftar confirm handles + runId idempotency. Never log the token.

Cloud Run min-instances 0 drops this store on scale-to-zero. Durable SoT is
Drift on the device after run-batch returns runId. Re-plan replaces the token.
"""

from __future__ import annotations

import secrets
from dataclasses import dataclass
from threading import Lock


@dataclass(frozen=True)
class PlanSnapshot:
    token: str
    phone_e164: str
    region: str
    locale: str
    task: str
    do_not_call: bool
    trigger: str


@dataclass(frozen=True)
class RunContext:
    batch_id: str
    correlation_id: str


class ConfirmHandleStore:
    def put(self, batch_id: str, contact_id: str, snapshot: PlanSnapshot) -> None:
        raise NotImplementedError

    def get(self, batch_id: str, contact_id: str) -> PlanSnapshot | None:
        raise NotImplementedError

    def delete(self, batch_id: str, contact_id: str) -> None:
        raise NotImplementedError

    def get_run_id(self, batch_id: str, contact_id: str) -> str | None:
        raise NotImplementedError

    def put_run_id(self, batch_id: str, contact_id: str, run_id: str) -> None:
        raise NotImplementedError

    def put_run_mask(self, run_id: str, phone_masked: str) -> None:
        raise NotImplementedError

    def get_run_mask(self, run_id: str) -> str | None:
        raise NotImplementedError

    def put_run_context(
        self,
        run_id: str,
        batch_id: str,
        correlation_id: str,
    ) -> None:
        raise NotImplementedError

    def get_run_context(self, run_id: str) -> RunContext | None:
        raise NotImplementedError


class InMemoryConfirmHandleStore(ConfirmHandleStore):
    def __init__(self) -> None:
        self._lock = Lock()
        self._snapshots: dict[tuple[str, str], PlanSnapshot] = {}
        self._run_ids: dict[tuple[str, str], str] = {}
        self._run_masks: dict[str, str] = {}
        self._run_contexts: dict[str, RunContext] = {}

    def put(self, batch_id: str, contact_id: str, snapshot: PlanSnapshot) -> None:
        with self._lock:
            self._snapshots[(batch_id, contact_id)] = snapshot

    def get(self, batch_id: str, contact_id: str) -> PlanSnapshot | None:
        with self._lock:
            return self._snapshots.get((batch_id, contact_id))

    def delete(self, batch_id: str, contact_id: str) -> None:
        with self._lock:
            self._snapshots.pop((batch_id, contact_id), None)

    def get_run_id(self, batch_id: str, contact_id: str) -> str | None:
        with self._lock:
            return self._run_ids.get((batch_id, contact_id))

    def put_run_id(self, batch_id: str, contact_id: str, run_id: str) -> None:
        with self._lock:
            self._run_ids[(batch_id, contact_id)] = run_id

    def put_run_mask(self, run_id: str, phone_masked: str) -> None:
        with self._lock:
            self._run_masks[run_id] = phone_masked

    def get_run_mask(self, run_id: str) -> str | None:
        with self._lock:
            return self._run_masks.get(run_id)

    def put_run_context(
        self,
        run_id: str,
        batch_id: str,
        correlation_id: str,
    ) -> None:
        with self._lock:
            self._run_contexts[run_id] = RunContext(
                batch_id=batch_id,
                correlation_id=correlation_id,
            )

    def get_run_context(self, run_id: str) -> RunContext | None:
        with self._lock:
            return self._run_contexts.get(run_id)


def new_confirm_handle() -> str:
    return secrets.token_urlsafe(32)


def token_matches(stored: str, presented: str) -> bool:
    if not stored or not presented:
        return False
    if len(stored) != len(presented):
        return False
    return secrets.compare_digest(stored, presented)
