#!/usr/bin/env python3
"""Stage 1.4 no-PSTN smoke — plan / run / get against daftar-call-e.

Reads URL and allowlist from $HOME/.daftar-owner-ops/. Never prints E.164,
confirm handles, or API keys. Does not dial. Does not set CALLE_ALLOW_DIAL.
Never waits for a CALL-E terminal status. Does not target the frozen Agentic
hostname daftar-closing-agent-1487285471.

Usage (from agent/):
  python3 scripts/smoke_calls_plan_run.py
"""

from __future__ import annotations

import json
import os
import subprocess
import sys
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
OUT_DIR = Path(__file__).resolve().parents[1] / "smoke_evidence"
FROZEN_HOST = "daftar-closing-agent-1487285471"
LEGAL_SERVICE = "daftar-call-e"
YE_PLACEHOLDER = "+967700000000"
C3_TASK = "C3-ECHO: collect 500 YER from Mohamed — do not reformat"
FAKE_GET_ID = "call_smoke_stage14_missing"
UNAUTH_GET_ID = "call_smoke_missing"


def _die(msg: str, code: int = 1) -> None:
    print(f"smoke_calls_plan_run: {msg}", file=sys.stderr)
    raise SystemExit(code)


def _mask_e164(phone: str) -> str:
    digits = phone[-4:] if len(phone) >= 4 else "????"
    return f"+…{digits}"


def _refuse_live_flags() -> None:
    joined = " ".join(sys.argv[1:])
    if "--live" in sys.argv[1:] or "--live" in joined:
        _die("refusing --live (Stage 1.4 smoke is no-PSTN)")
    wait_name = "create" + "_and_wait"
    if wait_name in joined:
        _die("refusing a waiting create")
    if os.environ.get("CALLE_ALLOW_DIAL", "") == "true":
        _die("refusing CALLE_ALLOW_DIAL=true in this process (kill switch stays false)")


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
    # User ADC cannot pass --audiences (gcloud: "Requires valid service account").
    # Same pattern as smoke_1_4.py / smoke_4_7_send_batch.py.
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


def _recipient(phone: str, region: str, contact_id: str | None = None) -> dict[str, Any]:
    return {
        "contactId": contact_id or str(uuid.uuid4()),
        "phoneE164": phone,
        "region": region,
        "locale": "en-US",
        "task": C3_TASK,
        "customer_name": "Mohamed Ali",
        "store_name": "Al-Ghanem Store",
        "amount_line": "500 YER",
        "doNotCall": False,
    }


def _plan_body(
    phone: str,
    region: str,
    *,
    dry_run: bool,
    extra_recipients: int = 0,
) -> dict[str, Any]:
    recipients = [_recipient(phone, region)]
    for _ in range(extra_recipients):
        recipients.append(_recipient(phone, region))
    return {
        "batchId": str(uuid.uuid4()),
        "correlationId": str(uuid.uuid4()),
        "trigger": "closeDay",
        "dryRun": dry_run,
        "locale": "ar",
        "recipients": recipients,
    }


def _assert_no_leak(raw: str, phone: str, *secrets: str) -> None:
    if phone and phone in raw:
        _die("response leaked full E.164")
    for secret in secrets:
        if secret and secret in raw:
            _die("response leaked a secret")


def _check(
    name: str,
    ok: bool,
    **fields: Any,
) -> dict[str, Any]:
    row = {"name": name, "pass": ok, **fields}
    status = "pass" if ok else "FAIL"
    print(f"[{status}] {name}")
    return row


def main() -> int:
    _refuse_live_flags()
    service_url = _service_url()
    phone = _allowlisted_phone()
    region = _region()
    masked = _mask_e164(phone)
    token = _identity_token()
    if not token:
        _die("empty identity token")

    checks: list[dict[str, Any]] = []

    code, _, raw = _http("GET", f"{service_url}/v1/calls/{UNAUTH_GET_ID}")
    _assert_no_leak(raw, phone)
    checks.append(_check("unauth_get_403", code == 403, http=code))

    code, _, raw = _http(
        "POST",
        f"{service_url}/v1/calls/plan-batch",
        body=_plan_body(phone, region, dry_run=True),
    )
    _assert_no_leak(raw, phone)
    checks.append(_check("unauth_plan_403", code == 403, http=code))

    dry_body = _plan_body(phone, region, dry_run=True)
    code, payload, raw = _http(
        "POST",
        f"{service_url}/v1/calls/plan-batch",
        token=token,
        body=dry_body,
    )
    _assert_no_leak(raw, phone)
    row = {}
    if isinstance(payload, dict) and isinstance(payload.get("results"), list) and payload["results"]:
        first = payload["results"][0]
        if isinstance(first, dict):
            row = first
    dry_ok = (
        code == 200
        and row.get("status") == "dryRun"
        and row.get("task") == C3_TASK
        and "confirmHandle" not in row
        and row.get("phoneMasked") == masked
    )
    checks.append(
        _check(
            "dry_run_plan",
            dry_ok,
            http=code,
            status=row.get("status"),
            phoneMasked=row.get("phoneMasked"),
        )
    )

    ye_body = _plan_body(YE_PLACEHOLDER, "YE", dry_run=True)
    ye_body["recipients"][0]["phoneE164"] = YE_PLACEHOLDER
    ye_body["recipients"][0]["region"] = "YE"
    code, payload, raw = _http(
        "POST",
        f"{service_url}/v1/calls/plan-batch",
        token=token,
        body=ye_body,
    )
    _assert_no_leak(raw, phone)
    _assert_no_leak(raw, YE_PLACEHOLDER)
    ye_row: dict[str, Any] = {}
    if isinstance(payload, dict) and isinstance(payload.get("results"), list) and payload["results"]:
        first = payload["results"][0]
        if isinstance(first, dict):
            ye_row = first
    ye_ok = (
        code == 200
        and ye_row.get("status") == "rejected"
        and ye_row.get("reason") == "unsupportedRegion"
        and "confirmHandle" not in ye_row
    )
    checks.append(
        _check(
            "ye_unsupported_region",
            ye_ok,
            http=code,
            status=ye_row.get("status"),
            reason=ye_row.get("reason"),
        )
    )

    cap_body = _plan_body(phone, region, dry_run=True, extra_recipients=5)
    code, _, raw = _http(
        "POST",
        f"{service_url}/v1/calls/plan-batch",
        token=token,
        body=cap_body,
    )
    _assert_no_leak(raw, phone)
    checks.append(_check("over_cap_400", code == 400, http=code))

    kill_body = _plan_body(phone, region, dry_run=False)
    code, payload, raw = _http(
        "POST",
        f"{service_url}/v1/calls/plan-batch",
        token=token,
        body=kill_body,
    )
    _assert_no_leak(raw, phone)
    kill_row: dict[str, Any] = {}
    if isinstance(payload, dict) and isinstance(payload.get("results"), list) and payload["results"]:
        first = payload["results"][0]
        if isinstance(first, dict):
            kill_row = first
    plan_kill_ok = (
        code == 200
        and kill_row.get("status") == "rejected"
        and kill_row.get("reason") == "killSwitch"
        and "confirmHandle" not in kill_row
    )
    checks.append(
        _check(
            "plan_kill_switch_row",
            plan_kill_ok,
            http=code,
            status=kill_row.get("status"),
            reason=kill_row.get("reason"),
        )
    )

    run_body = {
        "batchId": str(uuid.uuid4()),
        "correlationId": str(uuid.uuid4()),
        "recipients": [
            {
                "contactId": str(uuid.uuid4()),
                "confirmHandle": "smoke-dummy-handle-not-from-plan",
            }
        ],
    }
    code, payload, raw = _http(
        "POST",
        f"{service_url}/v1/calls/run-batch",
        token=token,
        body=run_body,
    )
    _assert_no_leak(raw, phone)
    run_ok = (
        code == 403
        and isinstance(payload, dict)
        and payload.get("detail") == "killSwitch"
        and payload.get("needsHuman") is True
    )
    checks.append(
        _check(
            "run_kill_switch_403",
            run_ok,
            http=code,
            detail=payload.get("detail") if isinstance(payload, dict) else None,
        )
    )

    code, payload, raw = _http(
        "GET",
        f"{service_url}/v1/calls/{FAKE_GET_ID}",
        token=token,
    )
    _assert_no_leak(raw, phone)
    get_ok = (
        code == 404
        and isinstance(payload, dict)
        and payload.get("detail") == "not_found"
    )
    checks.append(_check("get_missing_404", get_ok, http=code))

    all_pass = all(item.get("pass") for item in checks)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    report = {
        "stage": "1.4",
        "service": LEGAL_SERVICE,
        "phoneMasked": masked,
        "region": region,
        "checks": checks,
        "pass": all_pass,
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report_path = OUT_DIR / f"{stamp}_calls_plan_run.json"
    blob = json.dumps(report, indent=2)
    if phone in blob:
        _die("evidence leaked full E.164")
    report_path.write_text(blob + "\n", encoding="utf-8")
    print(f"phoneMasked={masked} overall_pass={all_pass} report={report_path}")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
