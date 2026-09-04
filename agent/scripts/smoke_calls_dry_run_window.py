#!/usr/bin/env python3
"""Demo-window dry-run subset against daftar-call-e.

No PSTN. No run-batch. Does not assert killSwitch (Cloud Run may have
CALLE_ALLOW_DIAL=true). Never prints E.164, confirm handles, or API keys.
Does not target the frozen Agentic hostname.

Usage (from repo):
  python3 agent/scripts/smoke_calls_dry_run_window.py
"""

from __future__ import annotations

import json
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
RESULT_FILE = OPS / "j9-dry-run-result.json"
FROZEN_HOST = "daftar-closing-agent-1487285471"
LEGAL_SERVICE = "daftar-call-e"
YE_PLACEHOLDER = "+967700000000"
C3_TASK = "C3-ECHO: collect 500 YER from Mohamed — do not reformat"
FAKE_GET_ID = "call_smoke_dry_window_missing"


def _die(msg: str, code: int = 1) -> None:
    print(f"smoke_calls_dry_run_window: {msg}", file=sys.stderr)
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


def _recipient(phone: str, region: str) -> dict[str, Any]:
    return {
        "contactId": str(uuid.uuid4()),
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


def _assert_no_leak(raw: str, phone: str) -> None:
    if phone and phone in raw:
        _die("response leaked full E.164")
    if "confirmHandle" in raw and '"confirmHandle"' in raw:
        # dry-run and YE must not include a handle key with a value
        pass


def _first_row(payload: Any) -> dict[str, Any]:
    if isinstance(payload, dict) and isinstance(payload.get("results"), list) and payload["results"]:
        first = payload["results"][0]
        if isinstance(first, dict):
            return first
    return {}


def _check(name: str, ok: bool, **fields: Any) -> dict[str, Any]:
    row = {"name": name, "pass": ok, **fields}
    status = "pass" if ok else "FAIL"
    print(f"[{status}] {name}")
    return row


def _write_result(payload: dict[str, Any]) -> None:
    OPS.mkdir(mode=0o700, exist_ok=True)
    tmp = RESULT_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    tmp.chmod(0o600)
    tmp.replace(RESULT_FILE)
    RESULT_FILE.chmod(0o600)


def main() -> int:
    service_url = _service_url()
    phone = _allowlisted_phone()
    region = _region()
    masked = _mask_e164(phone)
    token = _identity_token()
    if not token:
        _die("empty identity token")

    checks: list[dict[str, Any]] = []

    code, _, raw = _http(
        "POST",
        f"{service_url}/v1/calls/plan-batch",
        body=_plan_body(phone, region, dry_run=True),
    )
    _assert_no_leak(raw, phone)
    checks.append(_check("unauth_plan_403", code == 403, http=code))

    code, payload, raw = _http(
        "POST",
        f"{service_url}/v1/calls/plan-batch",
        token=token,
        body=_plan_body(phone, region, dry_run=True),
    )
    _assert_no_leak(raw, phone)
    row = _first_row(payload)
    dry_ok = (
        code == 200
        and row.get("status") == "dryRun"
        and row.get("task") == C3_TASK
        and not row.get("confirmHandle")
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
    if YE_PLACEHOLDER in raw:
        _die("response leaked YE placeholder")
    ye_row = _first_row(payload)
    ye_ok = (
        code == 200
        and ye_row.get("status") == "rejected"
        and ye_row.get("reason") == "unsupportedRegion"
        and not ye_row.get("confirmHandle")
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
    report = {
        "stage": "dry-run-window",
        "service": LEGAL_SERVICE,
        "phoneMasked": masked,
        "region": region,
        "checks": checks,
        "pass": all_pass,
        "finished_at": datetime.now(timezone.utc).isoformat(),
    }
    if phone in json.dumps(report):
        _die("report would leak E.164")
    _write_result(report)
    print(f"smoke_calls_dry_run_window: pass={all_pass} dest={masked} region={region}")
    return 0 if all_pass else 2


if __name__ == "__main__":
    raise SystemExit(main())
