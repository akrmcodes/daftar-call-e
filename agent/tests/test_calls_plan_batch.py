"""Stage 1.1 plan-batch — Daftar-local gates. RFC 555 numbers only. Never dial."""

from __future__ import annotations

import builtins
import sys
import types
import uuid
from pathlib import Path
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from calls.handles import InMemoryConfirmHandleStore
from calls.masking import mask_e164
from calls.router import get_call_settings, get_handle_store, router
from calls.settings import CallSettings, parse_allow_dial

CALLS_ROOT = Path(__file__).resolve().parents[1] / "calls"
OPENAPI_PATH = Path(__file__).resolve().parents[1] / "openapi.yaml"

# North American fictional 555 numbers (not a live DID).
TEST_PHONE = "+15555550100"
OTHER_NANP = "+15555550199"
YE_PHONE = "+967700000000"
SA_PHONE = "+966500000000"
C3_TASK = "C3-ECHO: collect 500 YER from Mohamed — do not reformat"

FORBIDDEN_WAIT = ("create_and_wait", "wait_for_result")
FORBIDDEN_SDK = ("calle", "CalleClient", "heycall-e.com")


class FakeCallsApi:
    def create(self, *args: Any, **kwargs: Any) -> None:
        raise AssertionError("CalleClient.calls.create must not run on plan-batch")

    def create_and_wait(self, *args: Any, **kwargs: Any) -> None:
        raise AssertionError("create_and_wait must not run on plan-batch")


class FakeCalleClient:
    def __init__(self, *args: Any, **kwargs: Any) -> None:
        raise AssertionError("CalleClient must not be constructed on plan-batch")

    calls = FakeCallsApi()


def _install_fake_calle(monkeypatch: pytest.MonkeyPatch) -> None:
    fake = types.ModuleType("calle")
    fake.CalleClient = FakeCalleClient
    monkeypatch.setitem(sys.modules, "calle", fake)
    real_import = builtins.__import__

    def guarded(name: str, *args: Any, **kwargs: Any) -> Any:
        if name == "calle" or name.startswith("calle."):
            raise AssertionError("plan-batch must not import calle")
        return real_import(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", guarded)


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
    )


def _app(
    settings: CallSettings,
    store: InMemoryConfirmHandleStore | None = None,
) -> tuple[TestClient, InMemoryConfirmHandleStore]:
    handles = store or InMemoryConfirmHandleStore()
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_call_settings] = lambda: settings
    app.dependency_overrides[get_handle_store] = lambda: handles
    return TestClient(app), handles


def _recipient(**overrides: Any) -> dict[str, Any]:
    row: dict[str, Any] = {
        "contactId": str(uuid.uuid4()),
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


def _body(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "batchId": str(uuid.uuid4()),
        "correlationId": str(uuid.uuid4()),
        "trigger": "closeDay",
        "dryRun": False,
        "locale": "ar",
        "recipients": [_recipient()],
    }
    payload.update(overrides)
    return payload


def test_calls_source_never_imports_developer_api() -> None:
    hits: list[str] = []
    for path in CALLS_ROOT.rglob("*.py"):
        text = path.read_text(encoding="utf-8")
        for needle in FORBIDDEN_WAIT:
            if needle in text:
                hits.append(f"{path.name}:{needle}")
        if path.name == "client.py":
            continue
        for needle in FORBIDDEN_SDK:
            if needle in text:
                hits.append(f"{path.name}:{needle}")
    assert hits == []
    client_src = (CALLS_ROOT / "client.py").read_text(encoding="utf-8")
    assert "from calle import CalleClient" in client_src
    assert "heycall-e.com" in client_src


def test_parse_allow_dial_is_exact_lowercase_true() -> None:
    assert parse_allow_dial("true") is True
    assert parse_allow_dial("TRUE") is False
    assert parse_allow_dial("1") is False
    assert parse_allow_dial("yes") is False
    assert parse_allow_dial("false") is False
    assert parse_allow_dial("") is False
    assert parse_allow_dial(None) is False


def test_mask_e164_last_four_only() -> None:
    assert mask_e164(TEST_PHONE) == "+…0100"
    assert TEST_PHONE not in mask_e164(TEST_PHONE)


def test_over_five_recipients_is_400() -> None:
    client, _ = _app(_settings())
    recipients = [_recipient() for _ in range(6)]
    response = client.post("/v1/calls/plan-batch", json=_body(recipients=recipients))
    assert response.status_code == 400
    assert response.json()["detail"] == "recipients_cap_exceeded"


def test_empty_recipients_is_400() -> None:
    client, _ = _app(_settings())
    response = client.post("/v1/calls/plan-batch", json=_body(recipients=[]))
    assert response.status_code == 400
    assert response.json()["detail"] == "recipients_cap_exceeded"


def test_extra_field_is_400() -> None:
    client, _ = _app(_settings())
    payload = _body()
    payload["unexpected"] = "nope"
    response = client.post("/v1/calls/plan-batch", json=payload)
    assert response.status_code == 400


def test_invalid_uuid_is_400() -> None:
    client, _ = _app(_settings())
    payload = _body(batchId="not-a-uuid")
    response = client.post("/v1/calls/plan-batch", json=payload)
    assert response.status_code == 400


def test_ye_and_plus_967_unsupported_region() -> None:
    client, _ = _app(_settings(phones=frozenset({YE_PHONE})))
    response = client.post(
        "/v1/calls/plan-batch",
        json=_body(recipients=[_recipient(phoneE164=YE_PHONE, region="YE")]),
    )
    assert response.status_code == 200
    row = response.json()["results"][0]
    assert row["status"] == "rejected"
    assert row["reason"] == "unsupportedRegion"
    assert row["readyToRun"] is False
    assert "confirmHandle" not in row


def test_not_allowlisted() -> None:
    client, _ = _app(_settings(phones=frozenset({TEST_PHONE})))
    response = client.post(
        "/v1/calls/plan-batch",
        json=_body(recipients=[_recipient(phoneE164=OTHER_NANP)]),
    )
    assert response.status_code == 200
    row = response.json()["results"][0]
    assert row["status"] == "rejected"
    assert row["reason"] == "notAllowlisted"
    assert "confirmHandle" not in row


def test_do_not_call() -> None:
    client, _ = _app(_settings())
    response = client.post(
        "/v1/calls/plan-batch",
        json=_body(recipients=[_recipient(doNotCall=True)]),
    )
    assert response.status_code == 200
    row = response.json()["results"][0]
    assert row["status"] == "rejected"
    assert row["reason"] == "dnc"
    assert "confirmHandle" not in row


def test_nanp_region_must_equal_allowlist_region() -> None:
    client, _ = _app(_settings(region="US"))
    response = client.post(
        "/v1/calls/plan-batch",
        json=_body(recipients=[_recipient(region="CA")]),
    )
    assert response.status_code == 200
    row = response.json()["results"][0]
    assert row["status"] == "rejected"
    assert row["reason"] == "unsupportedRegion"


def test_sa_phone_with_us_region_unsupported() -> None:
    client, _ = _app(_settings(phones=frozenset({SA_PHONE}), region="US"))
    response = client.post(
        "/v1/calls/plan-batch",
        json=_body(recipients=[_recipient(phoneE164=SA_PHONE, region="US")]),
    )
    assert response.status_code == 200
    assert response.json()["results"][0]["reason"] == "unsupportedRegion"


def test_kill_switch_off_dry_run_false() -> None:
    client, _ = _app(_settings(allow_dial=False))
    response = client.post("/v1/calls/plan-batch", json=_body(dryRun=False))
    assert response.status_code == 200
    row = response.json()["results"][0]
    assert row["status"] == "rejected"
    assert row["reason"] == "killSwitch"
    assert response.status_code != 403
    assert "confirmHandle" not in row


def test_kill_switch_off_dry_run_echoes_task() -> None:
    client, _ = _app(_settings(allow_dial=False))
    response = client.post("/v1/calls/plan-batch", json=_body(dryRun=True))
    assert response.status_code == 200
    row = response.json()["results"][0]
    assert row["status"] == "dryRun"
    assert row["readyToRun"] is False
    assert row["task"] == C3_TASK
    assert "confirmHandle" not in row
    assert "reason" not in row


def test_happy_path_issues_handle_without_logging_secrets(
    monkeypatch: pytest.MonkeyPatch,
    capsys: pytest.CaptureFixture[str],
) -> None:
    _install_fake_calle(monkeypatch)
    store = InMemoryConfirmHandleStore()
    client, store = _app(_settings(allow_dial=True), store)
    payload = _body(dryRun=False)
    contact_id = payload["recipients"][0]["contactId"]
    batch_id = payload["batchId"]
    response = client.post("/v1/calls/plan-batch", json=payload)
    assert response.status_code == 200
    row = response.json()["results"][0]
    assert row["status"] == "planned"
    assert row["readyToRun"] is True
    assert row["task"] == C3_TASK
    handle = row["confirmHandle"]
    assert isinstance(handle, str) and len(handle) >= 16
    assert store.get(batch_id, contact_id) is not None
    assert store.get(batch_id, contact_id).token == handle
    captured = capsys.readouterr()
    combined = captured.out + captured.err
    assert handle not in combined
    assert TEST_PHONE not in combined
    assert "daftar.agent.call" in combined
    assert '"action":"plan"' in combined
    assert mask_e164(TEST_PHONE) in combined


def test_replan_replaces_handle() -> None:
    store = InMemoryConfirmHandleStore()
    client, store = _app(_settings(allow_dial=True), store)
    payload = _body(dryRun=False)
    first = client.post("/v1/calls/plan-batch", json=payload)
    second = client.post("/v1/calls/plan-batch", json=payload)
    a = first.json()["results"][0]["confirmHandle"]
    b = second.json()["results"][0]["confirmHandle"]
    assert a != b
    contact_id = payload["recipients"][0]["contactId"]
    assert store.get(payload["batchId"], contact_id) is not None
    assert store.get(payload["batchId"], contact_id).token == b


def test_plan_never_calls_create(monkeypatch: pytest.MonkeyPatch) -> None:
    _install_fake_calle(monkeypatch)
    client, _ = _app(_settings(allow_dial=True))
    response = client.post("/v1/calls/plan-batch", json=_body(dryRun=False))
    assert response.status_code == 200
    assert response.json()["results"][0]["status"] == "planned"


def test_invalid_phone() -> None:
    client, _ = _app(_settings())
    response = client.post(
        "/v1/calls/plan-batch",
        json=_body(recipients=[_recipient(phoneE164="555-0100")]),
    )
    assert response.status_code == 200
    assert response.json()["results"][0]["reason"] == "invalidPhone"


def test_openapi_has_plan_run_and_get() -> None:
    import yaml

    spec = yaml.safe_load(OPENAPI_PATH.read_text(encoding="utf-8"))
    assert spec["info"]["version"] == "2.7.0"
    paths = spec["paths"]
    assert "/v1/calls/plan-batch" in paths
    assert "/v1/calls/run-batch" in paths
    assert "/v1/calls/{runId}" in paths
    assert "get" in paths["/v1/calls/{runId}"]
    post = paths["/v1/calls/run-batch"]["post"]
    assert post["security"] == [{"GoogleIdToken": []}]
    get_call = paths["/v1/calls/{runId}"]["get"]
    assert get_call["security"] == [{"GoogleIdToken": []}]
    assert "RunBatchRequest" in spec["components"]["schemas"]
    assert "CallGetResponse" in spec["components"]["schemas"]
    enum = spec["components"]["schemas"]["ProposalTool"]["enum"]
    assert len(enum) == 8
