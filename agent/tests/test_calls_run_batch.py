"""Stage 1.2 run-batch — fake create, RFC 555 numbers only. Never wait."""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from uuid import uuid4

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from calls.handles import InMemoryConfirmHandleStore, PlanSnapshot, new_confirm_handle
from calls.masking import mask_e164
from calls.router import get_call_creator, get_call_settings, get_handle_store, router
from calls.settings import CallSettings

CALLS_ROOT = Path(__file__).resolve().parents[1] / "calls"

TEST_PHONE = "+15555550100"
OTHER_NANP = "+15555550199"
YE_PHONE = "+967700000000"
C3_TASK = "C3-ECHO: collect 500 YER from Mohamed — do not reformat"
FAKE_RUN_ID = "call_test_queued_1"
FAKE_KEY = "test-api-key-MUST-NOT-APPEAR"


@dataclass
class RecordingCreator:
    calls: list[dict[str, Any]] = field(default_factory=list)
    fail: bool = False
    next_id: str = FAKE_RUN_ID

    def create(self, **kwargs: Any) -> str:
        self.calls.append(kwargs)
        if self.fail:
            raise RuntimeError("upstream")
        return self.next_id

    def create_and_wait(self, **kwargs: Any) -> str:
        raise AssertionError("create_and_wait must not run on run-batch")


def _settings(
    *,
    allow_dial: bool = True,
    phones: frozenset[str] | None = None,
    region: str = "US",
) -> CallSettings:
    return CallSettings(
        allow_dial=allow_dial,
        allowlist=phones if phones is not None else frozenset({TEST_PHONE}),
        allowlist_region=region,
        api_key_file="/tmp/not-used-in-tests",
    )


def _app(
    settings: CallSettings,
    store: InMemoryConfirmHandleStore | None = None,
    creator: RecordingCreator | None = None,
) -> tuple[TestClient, InMemoryConfirmHandleStore, RecordingCreator]:
    handles = store or InMemoryConfirmHandleStore()
    fake = creator or RecordingCreator()
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_call_settings] = lambda: settings
    app.dependency_overrides[get_handle_store] = lambda: handles
    app.dependency_overrides[get_call_creator] = lambda: fake
    return TestClient(app), handles, fake


def _plan_recipient(**overrides: Any) -> dict[str, Any]:
    row: dict[str, Any] = {
        "contactId": str(uuid4()),
        "phoneE164": TEST_PHONE,
        "region": "US",
        "locale": "en-US",
        "task": C3_TASK,
        "customer_name": "Mohamed Ali",
        "store_name": "Al-Ghanem Store",
        "amount_line": "500 YER",
        "doNotCall": False,
    }
    row.update(overrides)
    return row


def _plan_body(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "batchId": str(uuid4()),
        "correlationId": str(uuid4()),
        "trigger": "closeDay",
        "dryRun": False,
        "locale": "ar",
        "recipients": [_plan_recipient()],
    }
    payload.update(overrides)
    return payload


def _plan_then_run(
    client: TestClient,
    *,
    plan: dict[str, Any] | None = None,
    handle_override: str | None = None,
    drop_handle: bool = False,
) -> tuple[Any, dict[str, Any]]:
    payload = plan if plan is not None else _plan_body()
    planned = client.post("/v1/calls/plan-batch", json=payload)
    assert planned.status_code == 200, planned.text
    row = planned.json()["results"][0]
    run_row: dict[str, Any] = {"contactId": payload["recipients"][0]["contactId"]}
    if not drop_handle:
        run_row["confirmHandle"] = (
            handle_override if handle_override is not None else row["confirmHandle"]
        )
    run_body = {
        "batchId": payload["batchId"],
        "correlationId": payload["correlationId"],
        "recipients": [run_row],
    }
    return client.post("/v1/calls/run-batch", json=run_body), payload


def test_missing_handle_is_400() -> None:
    client, _, fake = _app(_settings())
    response, _ = _plan_then_run(client, drop_handle=True)
    assert response.status_code == 400
    assert fake.calls == []


def test_empty_handle_is_400() -> None:
    client, _, fake = _app(_settings())
    response, _ = _plan_then_run(client, handle_override="")
    assert response.status_code == 400
    assert fake.calls == []


def test_kill_switch_off_is_403() -> None:
    client, _, fake = _app(_settings(allow_dial=False))
    response = client.post(
        "/v1/calls/run-batch",
        json={
            "batchId": str(uuid4()),
            "correlationId": str(uuid4()),
            "recipients": [
                {"contactId": str(uuid4()), "confirmHandle": "token-without-plan"}
            ],
        },
    )
    assert response.status_code == 403
    body = response.json()
    assert body["detail"] == "killSwitch"
    assert body["needsHuman"] is True
    assert fake.calls == []


def test_wrong_handle_rejected_no_create() -> None:
    client, _, fake = _app(_settings())
    response, _ = _plan_then_run(client, handle_override="not-the-plan-token")
    assert response.status_code == 200
    row = response.json()["results"][0]
    assert row["status"] == "rejected"
    assert row["reason"] == "invalidHandle"
    assert "runId" not in row
    assert fake.calls == []


def test_happy_path_queues_without_logging_secrets(
    capsys: pytest.CaptureFixture[str],
) -> None:
    client, store, fake = _app(_settings(allow_dial=True))
    payload = _plan_body()
    planned = client.post("/v1/calls/plan-batch", json=payload)
    assert planned.status_code == 200
    handle = planned.json()["results"][0]["confirmHandle"]
    contact_id = payload["recipients"][0]["contactId"]
    response = client.post(
        "/v1/calls/run-batch",
        json={
            "batchId": payload["batchId"],
            "correlationId": payload["correlationId"],
            "recipients": [{"contactId": contact_id, "confirmHandle": handle}],
        },
    )
    assert response.status_code == 200
    body = response.json()
    row = body["results"][0]
    assert row["status"] == "queued"
    assert row["runId"] == FAKE_RUN_ID
    assert body["needsHuman"] is False
    assert store.get_run_id(payload["batchId"], contact_id) == FAKE_RUN_ID
    assert store.get(payload["batchId"], contact_id) is None
    assert len(fake.calls) == 1
    created = fake.calls[0]
    assert created["task"] == C3_TASK
    assert created["phone"] == TEST_PHONE
    assert created["region"] == "US"
    assert created["locale"] == "en-US"
    assert created["idempotency_key"] == f"{payload['batchId']}:{contact_id}"
    assert created["metadata"]["batchId"] == payload["batchId"]
    assert created["metadata"]["contactId"] == contact_id
    assert created["metadata"]["trigger"] == "closeDay"
    captured = capsys.readouterr()
    combined = captured.out + captured.err
    assert handle not in combined
    assert TEST_PHONE not in combined
    assert FAKE_KEY not in combined
    assert '"action":"run"' in combined
    assert mask_e164(TEST_PHONE) in combined
    assert FAKE_RUN_ID in combined


def test_second_run_is_skipped_duplicate() -> None:
    client, _, fake = _app(_settings())
    first, payload = _plan_then_run(client)
    assert first.json()["results"][0]["status"] == "queued"
    # Handle consumed; replay with a dummy handle still hits runId store first.
    second = client.post(
        "/v1/calls/run-batch",
        json={
            "batchId": payload["batchId"],
            "correlationId": payload["correlationId"],
            "recipients": [
                {
                    "contactId": payload["recipients"][0]["contactId"],
                    "confirmHandle": "already-consumed-handle-value",
                }
            ],
        },
    )
    assert second.status_code == 200
    row = second.json()["results"][0]
    assert row["status"] == "skippedDuplicate"
    assert row["runId"] == FAKE_RUN_ID
    assert len(fake.calls) == 1


def test_ye_snapshot_rejected_no_create() -> None:
    store = InMemoryConfirmHandleStore()
    client, store, fake = _app(
        _settings(allow_dial=True, phones=frozenset({YE_PHONE})),
        store,
    )
    token = new_confirm_handle()
    contact_id = str(uuid4())
    batch_id = str(uuid4())
    store.put(
        batch_id,
        contact_id,
        PlanSnapshot(
            token=token,
            phone_e164=YE_PHONE,
            region="YE",
            locale="ar",
            task=C3_TASK,
            do_not_call=False,
            trigger="closeDay",
        ),
    )
    response = client.post(
        "/v1/calls/run-batch",
        json={
            "batchId": batch_id,
            "correlationId": str(uuid4()),
            "recipients": [{"contactId": contact_id, "confirmHandle": token}],
        },
    )
    assert response.status_code == 200
    assert response.json()["results"][0]["reason"] == "unsupportedRegion"
    assert fake.calls == []


def test_not_allowlisted_at_run_no_create() -> None:
    store = InMemoryConfirmHandleStore()
    plan_client, store, _ = _app(_settings(allow_dial=True, phones=frozenset({TEST_PHONE})), store)
    plan = _plan_body()
    planned = plan_client.post("/v1/calls/plan-batch", json=plan)
    handle = planned.json()["results"][0]["confirmHandle"]
    run_client, _, fake = _app(
        _settings(allow_dial=True, phones=frozenset({OTHER_NANP})),
        store,
    )
    response = run_client.post(
        "/v1/calls/run-batch",
        json={
            "batchId": plan["batchId"],
            "correlationId": plan["correlationId"],
            "recipients": [
                {
                    "contactId": plan["recipients"][0]["contactId"],
                    "confirmHandle": handle,
                }
            ],
        },
    )
    assert response.status_code == 200
    assert response.json()["results"][0]["reason"] == "notAllowlisted"
    assert fake.calls == []


def test_over_five_is_400() -> None:
    client, _, fake = _app(_settings())
    recipients = [
        {"contactId": str(uuid4()), "confirmHandle": "x"} for _ in range(6)
    ]
    response = client.post(
        "/v1/calls/run-batch",
        json={
            "batchId": str(uuid4()),
            "correlationId": str(uuid4()),
            "recipients": recipients,
        },
    )
    assert response.status_code == 400
    assert fake.calls == []


def test_create_failure_sets_needs_human() -> None:
    fake = RecordingCreator(fail=True)
    client, _, fake = _app(_settings(), creator=fake)
    response, _ = _plan_then_run(client)
    assert response.status_code == 200
    body = response.json()
    assert body["results"][0]["status"] == "failed"
    assert body["needsHuman"] is True


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
    assert "TASK_RESULT_SCHEMA" in client_src
    assert "RECIPIENT_RESULT_SCHEMA" in client_src
    assert "create_and_wait" not in client_src
