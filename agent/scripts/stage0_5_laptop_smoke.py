#!/usr/bin/env python3
"""Gate 0 laptop smoke: calle-ai==0.7.0 create_and_wait to the owner US DID.

Never print CALLE_API_KEY or a full E.164. Does not mutate Cloud Run.
Requires CALLE_ALLOW_DIAL=true in this process only.
"""

from __future__ import annotations

import json
import os
import sys
import uuid
from datetime import datetime, timezone
from pathlib import Path

OPS = Path.home() / ".daftar-owner-ops"
KEY_FILE = OPS / "calle-api-key"
LIST_FILE = OPS / "calle-allowlist"
REGION_FILE = OPS / "calle-allowlist-region"
IDEM_FILE = OPS / "stage0_5-idempotency-key"
RESULT_FILE = OPS / "stage0_5-result.json"
PROD_BASE = "https://api.heycall-e.com"
TASK = (
    "This is a brief Daftar connectivity test. Call the recipient. "
    "Identify as an automated test, not a human collections agent. "
    "Ask if they can hear clearly. Then end the call. "
    "Do not discuss debt, money, names, or collections."
)
RESULT_SCHEMA = {
    "type": "object",
    "required": ["can_hear_clearly"],
    "properties": {
        "can_hear_clearly": {
            "type": "string",
            "enum": ["yes", "no", "unknown"],
            "description": (
                "yes if the recipient said they can hear. "
                "no if they said they cannot. "
                "unknown if they did not answer or evidence is unclear."
            ),
        },
    },
    "additionalProperties": False,
}


def _die(msg: str, code: int = 1) -> None:
    print(f"stage0_5: {msg}", file=sys.stderr)
    raise SystemExit(code)


def _mask_e164(phone: str) -> str:
    digits = phone[-4:] if len(phone) >= 4 else "????"
    return f"+…{digits}"


def _write_result(payload: dict) -> None:
    OPS.mkdir(mode=0o700, exist_ok=True)
    tmp = RESULT_FILE.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(payload, indent=2, default=str) + "\n", encoding="utf-8")
    tmp.chmod(0o600)
    tmp.replace(RESULT_FILE)
    RESULT_FILE.chmod(0o600)


def _error_code(exc: BaseException) -> str:
    for attr in ("code", "error", "status_code"):
        val = getattr(exc, attr, None)
        if val is not None and not callable(val):
            return str(val)
    body = getattr(exc, "body", None) or getattr(exc, "response", None)
    if isinstance(body, dict):
        err = body.get("error")
        if isinstance(err, dict) and err.get("code"):
            return str(err["code"])
    text = str(exc)
    for needle in (
        "credential_grant_unavailable",
        "unauthorized",
        "forbidden",
        "insufficient_balance",
        "unsupported_region",
        "invalid_phone",
        "invalid_recipient",
        "not_found",
    ):
        if needle in text:
            return needle
    return type(exc).__name__


def main() -> int:
    if os.environ.get("CALLE_ALLOW_DIAL") != "true":
        _die("CALLE_ALLOW_DIAL must be exactly true in this process (file on disk stays false)")

    dial_file = OPS / "calle-allow-dial"
    if dial_file.is_file() and dial_file.read_text(encoding="utf-8").strip() == "true":
        _die("calle-allow-dial file must stay false; only the process env may be true")

    if not KEY_FILE.is_file() or not LIST_FILE.is_file() or not REGION_FILE.is_file():
        _die("missing owner-ops key, allowlist, or region file")

    api_key = KEY_FILE.read_text(encoding="utf-8").strip()
    phone = LIST_FILE.read_text(encoding="utf-8").strip()
    region = REGION_FILE.read_text(encoding="utf-8").strip()
    if "," in phone or "\n" in phone:
        _die("allowlist must be a single E.164 for Gate 0")
    if not (phone.startswith("+1") and phone[1:].isdigit() and len(phone) == 12):
        _die("allowlist is not a US E.164 of expected length")
    if region != "US":
        _die("CALLE_ALLOWLIST_REGION must be US")
    if len(api_key) < 8:
        _die("API key file looks empty")

    masked = _mask_e164(phone)
    if not IDEM_FILE.is_file():
        IDEM_FILE.write_text(str(uuid.uuid4()), encoding="utf-8")
        IDEM_FILE.chmod(0o600)
    idem = IDEM_FILE.read_text(encoding="utf-8").strip()
    if not idem:
        _die("empty idempotency key file")

    try:
        from importlib.metadata import version as pkg_version
        from calle import CalleClient
    except ImportError:
        _die("calle-ai is not installed in this interpreter")

    try:
        ver = pkg_version("calle-ai")
    except Exception:  # noqa: BLE001
        ver = "unknown"
    print(f"stage0_5: calle-ai={ver} base={PROD_BASE} dest={masked} region={region}")
    print("stage0_5: answer Linphone now; waiting up to 300s")

    client = CalleClient(api_key=api_key, base_url=PROD_BASE, timeout=60.0)
    started = datetime.now(timezone.utc).isoformat()
    evidence: dict = {
        "started_at": started,
        "masked_phone": masked,
        "region": region,
        "locale": "en-US",
        "base_url": PROD_BASE,
        "calle_ai_version": ver,
        "idempotency_key_present": True,
    }
    try:
        call = client.calls.create_and_wait(
            task=TASK,
            recipients=[{"phones": [phone], "region": region, "locale": "en-US"}],
            result_schema=RESULT_SCHEMA,
            metadata={"workflow_run_id": "daftar-gate0-smoke"},
            idempotency_key=idem,
            timeout_seconds=300,
            interval_seconds=5,
        )
    except Exception as exc:  # noqa: BLE001 — record any SDK/HTTP failure
        code = _error_code(exc)
        evidence.update(
            {
                "ok": False,
                "error_code": code,
                "error_type": type(exc).__name__,
                "finished_at": datetime.now(timezone.utc).isoformat(),
            }
        )
        _write_result(evidence)
        print(f"stage0_5: FAIL error_code={code}", file=sys.stderr)
        if code in {
            "unauthorized",
            "forbidden",
            "insufficient_balance",
            "unsupported_region",
            "invalid_phone",
            "credential_grant_unavailable",
        }:
            print("stage0_5: STOP. Do not start Stage 1 UI.", file=sys.stderr)
        return 2
    finally:
        close = getattr(client, "close", None)
        if callable(close):
            close()

    status = call.get("status") if isinstance(call, dict) else None
    call_id = call.get("id") if isinstance(call, dict) else None
    structured = call.get("structured_result") if isinstance(call, dict) else None
    evidence.update(
        {
            "ok": True,
            "status": status,
            "call_id": call_id,
            "task_completed": call.get("task_completed") if isinstance(call, dict) else None,
            "structured_result": structured,
            "finished_at": datetime.now(timezone.utc).isoformat(),
        }
    )
    _write_result(evidence)
    print(
        f"stage0_5: status={status} call.id={call_id} "
        f"structured_result={json.dumps(structured, default=str)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
