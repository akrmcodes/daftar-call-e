"""Stage 1.3 GET /v1/calls/{runId} — fake get, RFC 555 numbers only. Never wait."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from calls.client import CallNotFoundError
from calls.masking import mask_e164
from calls.router import get_call_creator, get_call_settings, get_handle_store, router
from calls.settings import CallSettings

CALLS_ROOT = Path(__file__).resolve().parents[1] / "calls"

TEST_PHONE = "+15555550100"
FAKE_RUN_ID = "call_test_get_1"
FAKE_KEY = "test-api-key-MUST-NOT-APPEAR"


@dataclass
class FakeGetter:
    payload: dict[str, Any] | None = None
    error: Exception | None = None
    gets: list[str] = field(default_factory=list)

    def create(self, **kwargs: Any) -> str:
        raise AssertionError("create must not run on GET tests")

    def get(self, *, api_key_file: str, run_id: str) -> dict[str, Any]:
        self.gets.append(run_id)
        if self.error is not None:
            raise self.error
        assert self.payload is not None
        return self.payload

    def create_and_wait(self, **kwargs: Any) -> dict[str, Any]:
        raise AssertionError("create_and_wait must not run")

    def wait_for_result(self, **kwargs: Any) -> dict[str, Any]:
        raise AssertionError("wait_for_result must not run")


def _settings(*, allow_dial: bool = True) -> CallSettings:
    return CallSettings(
        allow_dial=allow_dial,
        allowlist=frozenset({TEST_PHONE}),
        allowlist_region="US",
        api_key_file="/tmp/not-used-in-tests",
    )


def _app(
    settings: CallSettings,
    fake: FakeGetter | None = None,
) -> tuple[TestClient, FakeGetter]:
    getter = fake or FakeGetter()
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_call_settings] = lambda: settings
    app.dependency_overrides[get_handle_store] = lambda: __import__(
        "calls.handles", fromlist=["InMemoryConfirmHandleStore"]
    ).InMemoryConfirmHandleStore()
    app.dependency_overrides[get_call_creator] = lambda: getter
    return TestClient(app), getter


def _queued_payload(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "id": FAKE_RUN_ID,
        "status": "queued",
        "recipients": [{"phones": [TEST_PHONE], "region": "US", "locale": "en-US"}],
    }
    payload.update(overrides)
    return payload


def test_queued_is_non_terminal_without_needs_human() -> None:
    client, fake = _app(_settings(), FakeGetter(payload=_queued_payload()))
    response = client.get(f"/v1/calls/{FAKE_RUN_ID}")
    assert response.status_code == 200
    body = response.json()
    assert body["runId"] == FAKE_RUN_ID
    assert body["status"] == "queued"
    assert body["terminal"] is False
    assert body["needsHuman"] is False
    assert fake.gets == [FAKE_RUN_ID]


def test_in_progress_is_non_terminal() -> None:
    client, _ = _app(
        _settings(),
        FakeGetter(payload=_queued_payload(status="in_progress")),
    )
    body = client.get(f"/v1/calls/{FAKE_RUN_ID}").json()
    assert body["terminal"] is False
    assert body["needsHuman"] is False


def test_completed_valid_outcome_and_int_amount() -> None:
    payload = _queued_payload(
        status="completed",
        task_completed=True,
        structured_result={"completed_count": 1},
        recipients=[
            {
                "phones": [TEST_PHONE],
                "structured_result": {
                    "outcome": "promised",
                    "promised_amount_minor": 500,
                    "promised_currency": "YER",
                },
            }
        ],
    )
    client, _ = _app(_settings(), FakeGetter(payload=payload))
    body = client.get(f"/v1/calls/{FAKE_RUN_ID}").json()
    assert body["terminal"] is True
    assert body["taskCompleted"] is True
    assert body["needsHuman"] is False
    sr = body["structuredResult"]
    assert sr["outcome"] == "promised"
    assert sr["promised_amount_minor"] == 500
    assert isinstance(sr["promised_amount_minor"], int)
    assert sr["completed_count"] == 1


def test_float_amount_coerced_to_int() -> None:
    payload = _queued_payload(
        status="completed",
        recipients=[
            {
                "phones": [TEST_PHONE],
                "structured_result": {
                    "outcome": "promised",
                    "promised_amount_minor": 500.0,
                },
            }
        ],
    )
    body = _app(_settings(), FakeGetter(payload=payload))[0].get(
        f"/v1/calls/{FAKE_RUN_ID}"
    ).json()
    assert body["structuredResult"]["promised_amount_minor"] == 500
    assert body["needsHuman"] is False


def test_fractional_amount_omitted_and_needs_human() -> None:
    payload = _queued_payload(
        status="completed",
        recipients=[
            {
                "phones": [TEST_PHONE],
                "structured_result": {
                    "outcome": "promised",
                    "promised_amount_minor": 500.5,
                },
            }
        ],
    )
    body = _app(_settings(), FakeGetter(payload=payload))[0].get(
        f"/v1/calls/{FAKE_RUN_ID}"
    ).json()
    assert "promised_amount_minor" not in body["structuredResult"]
    assert body["needsHuman"] is True


def test_terminal_missing_outcome_needs_human() -> None:
    payload = _queued_payload(
        status="failed",
        recipients=[{"phones": [TEST_PHONE], "structured_result": {}}],
    )
    body = _app(_settings(), FakeGetter(payload=payload))[0].get(
        f"/v1/calls/{FAKE_RUN_ID}"
    ).json()
    assert body["terminal"] is True
    assert body["needsHuman"] is True


def test_completed_without_outcome_is_not_needs_human() -> None:
    payload = _queued_payload(
        status="completed",
        task_completed=True,
        structured_result={"completed_count": 1},
        recipients=[{"phones": [TEST_PHONE]}],
    )
    body = _app(_settings(), FakeGetter(payload=payload))[0].get(
        f"/v1/calls/{FAKE_RUN_ID}"
    ).json()
    assert body["terminal"] is True
    assert body["taskCompleted"] is True
    assert body["needsHuman"] is False
    assert body.get("structuredResult") is None or body["structuredResult"].get(
        "outcome"
    ) is None


def test_full_e164_masked_in_response(capsys: pytest.CaptureFixture[str]) -> None:
    payload = _queued_payload(status="in_progress")
    client, _ = _app(_settings(), FakeGetter(payload=payload))
    response = client.get(f"/v1/calls/{FAKE_RUN_ID}")
    assert response.status_code == 200
    body = response.json()
    assert body["phoneMasked"] == mask_e164(TEST_PHONE)
    assert TEST_PHONE not in response.text
    captured = capsys.readouterr()
    combined = captured.out + captured.err
    assert TEST_PHONE not in combined
    assert FAKE_KEY not in combined
    assert "daftar.agent.call" not in combined


def test_ringing_get_does_not_emit_call_log(
    capsys: pytest.CaptureFixture[str],
) -> None:
    client, _ = _app(
        _settings(),
        FakeGetter(payload=_queued_payload(status="in_progress")),
    )
    client.get(f"/v1/calls/{FAKE_RUN_ID}")
    captured = capsys.readouterr()
    combined = captured.out + captured.err
    assert "daftar.agent.call" not in combined


def test_terminal_get_emits_action_terminal_with_context(
    capsys: pytest.CaptureFixture[str],
) -> None:
    from calls.handles import InMemoryConfirmHandleStore

    store = InMemoryConfirmHandleStore()
    batch_id = "batch-terminal-1"
    correlation_id = "corr-terminal-1"
    store.put_run_context(FAKE_RUN_ID, batch_id, correlation_id)
    store.put_run_mask(FAKE_RUN_ID, mask_e164(TEST_PHONE))

    payload = _queued_payload(
        status="completed",
        task_completed=True,
        structured_result={"completed_count": 1},
        recipients=[
            {
                "phones": [TEST_PHONE],
                "structured_result": {
                    "outcome": "promised",
                    "promised_amount_minor": 500,
                    "promised_currency": "YER",
                },
            }
        ],
    )
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_call_settings] = lambda: _settings()
    app.dependency_overrides[get_handle_store] = lambda: store
    app.dependency_overrides[get_call_creator] = lambda: FakeGetter(payload=payload)
    client = TestClient(app)

    response = client.get(f"/v1/calls/{FAKE_RUN_ID}")
    assert response.status_code == 200
    assert response.json()["terminal"] is True

    captured = capsys.readouterr()
    combined = captured.out + captured.err
    assert '"action":"terminal"' in combined
    assert '"correlationId":"corr-terminal-1"' in combined
    assert '"batchId":"batch-terminal-1"' in combined
    assert f'"runId":"{FAKE_RUN_ID}"' in combined
    assert mask_e164(TEST_PHONE) in combined
    assert '"outcome":"promised"' in combined
    assert TEST_PHONE not in combined
    assert "promised_amount_minor" not in combined
    assert "evidence_quote" not in combined
    assert "confirmHandle" not in combined


def test_sdk_not_found_is_404() -> None:
    client, fake = _app(
        _settings(),
        FakeGetter(error=CallNotFoundError()),
    )
    response = client.get(f"/v1/calls/{FAKE_RUN_ID}")
    assert response.status_code == 404
    assert response.json()["detail"] == "not_found"
    assert fake.gets == [FAKE_RUN_ID]


def test_kill_switch_off_still_allows_get() -> None:
    client, fake = _app(
        _settings(allow_dial=False),
        FakeGetter(payload=_queued_payload()),
    )
    response = client.get(f"/v1/calls/{FAKE_RUN_ID}")
    assert response.status_code == 200
    assert fake.gets == [FAKE_RUN_ID]


def test_empty_run_id_is_400() -> None:
    client, fake = _app(_settings(), FakeGetter(payload=_queued_payload()))
    response = client.get("/v1/calls/%20%20")
    assert response.status_code == 400
    assert fake.gets == []


def test_source_bans_wait_and_isolates_sdk_import() -> None:
    wait_hits: list[str] = []
    sdk_hits: list[str] = []
    for path in CALLS_ROOT.rglob("*.py"):
        text = path.read_text(encoding="utf-8")
        for needle in ("create_and_wait", "wait_for_result", "webhook_url"):
            if needle in text:
                wait_hits.append(f"{path.name}:{needle}")
        if path.name == "client.py":
            continue
        for needle in ("calle", "CalleClient", "heycall-e.com"):
            if needle in text:
                sdk_hits.append(f"{path.name}:{needle}")
    assert wait_hits == []
    assert sdk_hits == []
    client_src = (CALLS_ROOT / "client.py").read_text(encoding="utf-8")
    assert "from calle import CalleClient" in client_src
    assert "client.calls.create" in client_src
    assert "client.calls.get" in client_src
    assert "create_and_wait" not in client_src
    assert "wait_for_result" not in client_src
