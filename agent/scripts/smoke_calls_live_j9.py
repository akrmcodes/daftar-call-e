#!/usr/bin/env python3
"""One-shot live J.9 against daftar-call-e (demo window).

Places one consented CALL-E call via Cloud Run plan-batch then run-batch,
then polls GET. Never prints E.164, confirm handles, or API keys.
Does not import calle-ai. Does not target the frozen Agentic hostname.

  export DAFTAR_CALL_E_LIVE_J9=true
  python3 agent/scripts/smoke_calls_live_j9.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

OPS = Path.home() / ".daftar-owner-ops"
URL_FILE = OPS / "daftar-call-e-url"
LIST_FILE = OPS / "calle-allowlist"
REGION_FILE = OPS / "calle-allowlist-region"
RESULT_FILE = OPS / "j9-live-result.json"
FROZEN_HOST = "daftar-closing-agent-1487285471"
LEGAL_SERVICE = "daftar-call-e"
LIVE_TASK = (
    "This is a brief Daftar connectivity test through Cloud Run. "
    "Call the recipient. Identify as an automated test, not a human "
    "collections agent. Ask if they can hear clearly. Then end the call. "
    "Do not discuss debt, money, names, or collections."
)
POLL_INITIAL_S = 60
POLL_INTERVAL_S = 7
POLL_TIMEOUT_S = 600


def _die(msg: str, code: int = 1) -> None:
    print(f"smoke_calls_live_j9: {msg}", file=sys.stderr)
    raise SystemExit(code)


def _mask_e164(phone: str) -> str:
    digits = phone[-4:] if len(phone) >= 4 else "????"
    return f"+…{digits}"


def _read_ops(path: Path) -> str:
    if not path.is_file():
        _die(f"missing owner-ops file {path.name}")
    return path.read_text(encoding="utf-8").strip()


def _service_url() -> str:
    raw = _read_ops(URL_FILE)
    url = raw.splitlines()[0].strip().rstrip("/")
    if not url:
        _die("daftar-call-e-url is empty")
    if FROZEN_HOST in url:
        _die("refusing frozen Agentic hostname")
    if LEGAL_SERVICE not in url:
        _die("URL must be daftar-call-e")
    if not url.startswith("https://"):
        _die("URL must be https")
    return url


def _allowlisted_phone() -> str:
    raw = _read_ops(LIST_FILE)
    entries: list[str] = []
    for line in raw.splitlines():
        for part in line.split(","):
            item = part.strip()
            if item:
                entries.append(item)
    if not entries:
        _die("calle-allowlist is empty")
    return entries[0]


def _region() -> str:
    if REGION_FILE.is_file():
        value = _read_ops(REGION_FILE) or "US"
        return value.splitlines()[0].strip() or "US"
    return "US"


def _identity_token() -> str:
    try:
        return subprocess.check_output(
            ["gcloud", "auth", "print-identity-token"],
            text=True,
            stderr=subprocess.STDOUT,
        ).strip()
    except subprocess.CalledProcessError:
        _die("gcloud auth print-identity-token failed")


def _http(
    method: str,
    url: str,
    *,
    token: str | None = None,
    body: dict[str, Any] | None = None,
    timeout: int = 180,
) -> tuple[int, Any, str]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = Request(url, data=data, method=method)
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urlopen(req, timeout=timeout) as resp:
            raw = resp.read().decode("utf-8")
            payload: Any = json.loads(raw) if raw.strip() else None
            return resp.status, payload, raw
    except HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw) if raw.strip() else None
        except json.JSONDecodeError:
            payload = None
        return exc.code, payload, raw
    except URLError as exc:
        _die(f"request failed: {exc}")
    return 0, None, ""


def _assert_no_leak(raw: str, phone: str, handle: str | None = None) -> None:
    if phone and phone in raw:
        _die("response leaked full E.164")
    if handle and handle in raw:
        # GET/run must not echo the confirm handle
        _die("response leaked confirm handle")


def _redact_handle(obj: Any) -> Any:
    if isinstance(obj, dict):
        out: dict[str, Any] = {}
        for key, value in obj.items():
            if key == "confirmHandle":
                out[key] = "present" if value else None
            else:
                out[key] = _redact_handle(value)
        return out
    if isinstance(obj, list):
        return [_redact_handle(item) for item in obj]
    return obj


def _write_result(payload: dict[str, Any]) -> None:
    OPS.mkdir(mode=0o700, exist_ok=True)
    tmp = RESULT_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    tmp.chmod(0o600)
    tmp.replace(RESULT_FILE)
    RESULT_FILE.chmod(0o600)


def _plan_body(phone: str, region: str, contact_id: str, batch_id: str, correlation_id: str) -> dict[str, Any]:
    return {
        "batchId": batch_id,
        "correlationId": correlation_id,
        "trigger": "closeDay",
        "dryRun": False,
        "locale": "en",
        "recipients": [
            {
                "contactId": contact_id,
                "phoneE164": phone,
                "region": region,
                "locale": "en-US",
                "task": LIVE_TASK,
                "customer_name": "Mohamed",
                "store_name": "Daftar",
                "amount_line": "0.00 USD",
                "doNotCall": False,
            }
        ],
    }


def _plan_then_run(
    *,
    service_url: str,
    token: str,
    phone: str,
    region: str,
    contact_id: str,
    is_retry: bool,
) -> tuple[str | None, dict[str, Any]]:
    batch_id = str(uuid.uuid4())
    correlation_id = str(uuid.uuid4())
    code, payload, raw = _http(
        "POST",
        f"{service_url}/v1/calls/plan-batch",
        token=token,
        body=_plan_body(phone, region, contact_id, batch_id, correlation_id),
    )
    _assert_no_leak(raw, phone)
    row: dict[str, Any] = {}
    if isinstance(payload, dict) and isinstance(payload.get("results"), list) and payload["results"]:
        first = payload["results"][0]
        if isinstance(first, dict):
            row = first
    handle = row.get("confirmHandle") if isinstance(row.get("confirmHandle"), str) else None
    if code != 200 or not handle:
        return None, {
            "plan_http": code,
            "plan_status": row.get("status"),
            "plan_reason": row.get("reason"),
            "retry": is_retry,
        }
    run_code, run_payload, run_raw = _http(
        "POST",
        f"{service_url}/v1/calls/run-batch",
        token=token,
        body={
            "batchId": batch_id,
            "correlationId": correlation_id,
            "recipients": [
                {"contactId": contact_id, "confirmHandle": handle},
            ],
        },
        timeout=180,
    )
    _assert_no_leak(run_raw, phone, handle)
    run_row: dict[str, Any] = {}
    if (
        isinstance(run_payload, dict)
        and isinstance(run_payload.get("results"), list)
        and run_payload["results"]
    ):
        first = run_payload["results"][0]
        if isinstance(first, dict):
            run_row = first
    run_id = run_row.get("runId") if isinstance(run_row.get("runId"), str) else None
    invalid = run_row.get("reason") == "invalidHandle"
    meta = {
        "plan_http": code,
        "run_http": run_code,
        "run_status": run_row.get("status"),
        "run_reason": run_row.get("reason"),
        "needsHuman": run_payload.get("needsHuman") if isinstance(run_payload, dict) else None,
        "retry": is_retry,
        "invalidHandle": invalid,
        "phoneMasked": run_row.get("phoneMasked") or row.get("phoneMasked"),
    }
    if invalid and not is_retry:
        return _plan_then_run(
            service_url=service_url,
            token=token,
            phone=phone,
            region=region,
            contact_id=contact_id,
            is_retry=True,
        )
    if not run_id:
        return None, meta
    meta["runId"] = run_id
    return run_id, meta


def main() -> int:
    if os.environ.get("DAFTAR_CALL_E_LIVE_J9", "") != "true":
        _die("DAFTAR_CALL_E_LIVE_J9 must be exactly true")
    if os.environ.get("CALLE_API_KEY"):
        _die("unset CALLE_API_KEY; Cloud Run holds the secret")

    service_url = _service_url()
    phone = _allowlisted_phone()
    region = _region()
    masked = _mask_e164(phone)
    token = _identity_token()
    if not token:
        _die("empty identity token")

    contact_id = str(uuid.uuid4())
    started = datetime.now(timezone.utc).isoformat()
    print(
        f"smoke_calls_live_j9: dest={masked} region={region} "
        "Linphone must be Registered. Dialing via daftar-call-e."
    )
    run_id, meta = _plan_then_run(
        service_url=service_url,
        token=token,
        phone=phone,
        region=region,
        contact_id=contact_id,
        is_retry=False,
    )
    if not run_id:
        evidence = {
            "ok": False,
            "started_at": started,
            "phoneMasked": masked,
            "region": region,
            "plan_run": meta,
            "finished_at": datetime.now(timezone.utc).isoformat(),
        }
        _write_result(evidence)
        print("smoke_calls_live_j9: FAIL plan/run did not return runId", file=sys.stderr)
        return 2

    print(f"smoke_calls_live_j9: runId={run_id} waiting {POLL_INITIAL_S}s then polling GET")
    deadline = time.monotonic() + POLL_TIMEOUT_S
    time.sleep(POLL_INITIAL_S)
    last_get: dict[str, Any] = {}
    terminal = False
    while time.monotonic() < deadline:
        code, payload, raw = _http(
            "GET",
            f"{service_url}/v1/calls/{run_id}",
            token=token,
            timeout=60,
        )
        _assert_no_leak(raw, phone)
        redacted = _redact_handle(payload) if isinstance(payload, dict) else payload
        last_get = {
            "http": code,
            "payload": redacted,
        }
        if isinstance(payload, dict) and (payload.get("terminal") is True or payload.get("needsHuman") is True):
            terminal = True
            break
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            break
        time.sleep(min(POLL_INTERVAL_S, remaining))

    ok = terminal and isinstance(last_get.get("payload"), dict)
    status = None
    needs_human = None
    if isinstance(last_get.get("payload"), dict):
        status = last_get["payload"].get("status")
        needs_human = last_get["payload"].get("needsHuman")
    evidence = {
        "ok": bool(ok),
        "started_at": started,
        "phoneMasked": masked,
        "region": region,
        "runId": run_id,
        "plan_run": meta,
        "get": last_get,
        "terminal": terminal,
        "finished_at": datetime.now(timezone.utc).isoformat(),
    }
    blob = json.dumps(evidence, default=str)
    if phone in blob:
        _die("result would leak E.164")
    _write_result(evidence)
    print(
        f"smoke_calls_live_j9: ok={ok} dest={masked} region={region} "
        f"runId={run_id} status={status} needsHuman={needs_human} terminal={terminal}"
    )
    return 0 if ok else 2


if __name__ == "__main__":
    raise SystemExit(main())
