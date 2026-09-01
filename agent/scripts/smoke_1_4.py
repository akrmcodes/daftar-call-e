#!/usr/bin/env python3
"""Stage 1.4 live ADK smoke — list-apps, session, close-day, Mohamed debt.

Writes evidence JSON under agent/smoke_evidence/ (gitignored optional).
Requires: gcloud auth, network. Uses identity token for Cloud Run invoker.
"""

from __future__ import annotations

import json
import subprocess
import sys
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

SERVICE_URL = "https://daftar-closing-agent-1487285471.us-central1.run.app"
APP = "closing_agent"
PROJECT = "daftar-closing-agent"
LEDGER_ID = "11111111-1111-4111-8111-111111111111"
CONTACT_MOHAMED = "33333333-3333-4333-8333-333333333333"
OUT_DIR = Path(__file__).resolve().parents[1] / "smoke_evidence"


def identity_token() -> str:
    return subprocess.check_output(
        ["gcloud", "auth", "print-identity-token"],
        text=True,
    ).strip()


def http_json(
    method: str,
    path: str,
    token: str,
    body: dict[str, Any] | None = None,
    *,
    retries: int = 3,
) -> tuple[int, Any]:
    url = f"{SERVICE_URL}{path}"
    data = None if body is None else json.dumps(body).encode("utf-8")
    last_err: Exception | None = None
    for attempt in range(1, retries + 1):
        req = Request(url, data=data, method=method)
        req.add_header("Authorization", f"Bearer {token}")
        if body is not None:
            req.add_header("Content-Type", "application/json")
        try:
            with urlopen(req, timeout=180) as resp:
                raw = resp.read().decode("utf-8")
                payload: Any = json.loads(raw) if raw.strip() else None
                return resp.status, payload
        except HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            # Retry transient Vertex / gateway failures
            if exc.code in (429, 500, 502, 503) and attempt < retries:
                time.sleep(5 * attempt)
                last_err = exc
                continue
            try:
                payload = json.loads(raw) if raw.strip().startswith("{") or raw.strip().startswith("[") else raw
            except json.JSONDecodeError:
                payload = raw
            return exc.code, payload
        except URLError as exc:
            last_err = exc
            if attempt < retries:
                time.sleep(5 * attempt)
                continue
            raise
    raise RuntimeError(f"request failed after retries: {last_err}")


def daftar_context(goal_text: str, correlation_id: str) -> dict[str, Any]:
    return {
        "correlationId": correlation_id,
        "locale": "en",
        "merchantLocalDay": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "ledgers": [{"id": LEDGER_ID, "name": "Customers"}],
        "voiceHints": [
            {
                "contactId": CONTACT_MOHAMED,
                "displayName": "Mohamed",
                "phone": "+967700000000",
            }
        ],
        "isMultiCurrencyEnabled": False,
        "defaultCurrency": "YER",
        "goalText": goal_text,
    }


def extract_function_responses(events: Any) -> list[dict[str, Any]]:
    """Walk ADK event list for functionResponse parts."""
    found: list[dict[str, Any]] = []
    if not isinstance(events, list):
        return found
    for event in events:
        if not isinstance(event, dict):
            continue
        content = event.get("content") or {}
        parts = content.get("parts") or []
        if not isinstance(parts, list):
            continue
        for part in parts:
            if not isinstance(part, dict):
                continue
            fr = part.get("functionResponse")
            if isinstance(fr, dict):
                found.append(
                    {
                        "name": fr.get("name"),
                        "response": fr.get("response"),
                    }
                )
    return found


def is_proposal(obj: Any) -> bool:
    return (
        isinstance(obj, dict)
        and isinstance(obj.get("proposalId"), str)
        and isinstance(obj.get("tool"), str)
        and isinstance(obj.get("payload"), dict)
        and "confirmRequired" in obj
    )


def proposals_from_responses(responses: list[dict[str, Any]]) -> list[dict[str, Any]]:
    out: list[dict[str, Any]] = []
    for item in responses:
        resp = item.get("response")
        if is_proposal(resp):
            out.append(resp)
        elif isinstance(resp, dict) and is_proposal(resp.get("result")):
            out.append(resp["result"])
    return out


def closing_plan_step_count(proposals: list[dict[str, Any]]) -> int:
    for p in proposals:
        if p.get("tool") == "propose_closing_plan":
            steps = (p.get("payload") or {}).get("steps")
            if isinstance(steps, list):
                return len(steps)
    return 0


def debt_amount_minor(proposals: list[dict[str, Any]]) -> Any:
    for p in proposals:
        if p.get("tool") == "propose_debt":
            return (p.get("payload") or {}).get("amountMinor")
    return None


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    report: dict[str, Any] = {
        "startedAt": stamp,
        "serviceUrl": SERVICE_URL,
        "checks": {},
    }
    token = identity_token()

    # 1) list-apps
    code, apps = http_json("GET", "/list-apps", token)
    ok_apps = code == 200 and isinstance(apps, list) and APP in apps
    report["checks"]["list_apps"] = {"http": code, "body": apps, "pass": ok_apps}
    print(f"[1] list-apps HTTP {code} → {apps} pass={ok_apps}")

    # 2) session create
    user_id = "smoke-1-4"
    session_id = f"smoke-{int(time.time())}"
    corr_close = str(uuid.uuid4())
    code, sess = http_json(
        "POST",
        f"/apps/{APP}/users/{user_id}/sessions/{session_id}",
        token,
        {"stateDelta": {"daftarContext": daftar_context("close my day", corr_close)}},
    )
    ok_sess = code == 200
    report["checks"]["session_create"] = {
        "http": code,
        "sessionId": session_id,
        "pass": ok_sess,
    }
    print(f"[2] session create HTTP {code} id={session_id} pass={ok_sess}")

    # 3) close my day
    code, close_events = http_json(
        "POST",
        "/run",
        token,
        {
            "appName": APP,
            "userId": user_id,
            "sessionId": session_id,
            "stateDelta": {
                "daftarContext": daftar_context("close my day", corr_close)
            },
            "newMessage": {
                "role": "user",
                "parts": [{"text": "close my day"}],
            },
        },
        retries=4,
    )
    close_responses = extract_function_responses(close_events)
    close_proposals = proposals_from_responses(close_responses)
    step_count = closing_plan_step_count(close_proposals)
    tool_names = sorted({r.get("name") for r in close_responses if r.get("name")})
    # Pass: ≥3 closing-plan steps OR ≥3 distinct tool calls that form a multi-step plan
    ok_close = (
        code == 200
        and (step_count >= 3 or len(tool_names) >= 3 or len(close_proposals) >= 3)
    )
    report["checks"]["close_my_day"] = {
        "http": code,
        "correlationId": corr_close,
        "toolNames": tool_names,
        "proposals": [
            {"tool": p.get("tool"), "proposalId": p.get("proposalId"), "payloadKeys": list((p.get("payload") or {}).keys())}
            for p in close_proposals
        ],
        "closingPlanSteps": step_count,
        "pass": ok_close,
    }
    (OUT_DIR / f"{stamp}_close_day.json").write_text(
        json.dumps(close_events, indent=2, ensure_ascii=False)[:500_000],
        encoding="utf-8",
    )
    print(
        f"[3] close my day HTTP {code} tools={tool_names} "
        f"steps={step_count} proposals={len(close_proposals)} pass={ok_close}"
    )

    # 4) Mohamed owes 500 (fresh session)
    session_debt = f"smoke-debt-{int(time.time())}"
    corr_debt = str(uuid.uuid4())
    code, _ = http_json(
        "POST",
        f"/apps/{APP}/users/{user_id}/sessions/{session_debt}",
        token,
        {
            "stateDelta": {
                "daftarContext": daftar_context("Mohamed owes 500", corr_debt)
            }
        },
    )
    code, debt_events = http_json(
        "POST",
        "/run",
        token,
        {
            "appName": APP,
            "userId": user_id,
            "sessionId": session_debt,
            "stateDelta": {
                "daftarContext": daftar_context("Mohamed owes 500", corr_debt)
            },
            "newMessage": {
                "role": "user",
                "parts": [{"text": "Mohamed owes 500"}],
            },
        },
        retries=4,
    )
    debt_responses = extract_function_responses(debt_events)
    debt_proposals = proposals_from_responses(debt_responses)
    amount = debt_amount_minor(debt_proposals)
    ok_debt = (
        code == 200
        and any(p.get("tool") == "propose_debt" for p in debt_proposals)
        and isinstance(amount, int)
        and not isinstance(amount, bool)
        and amount == 500
    )
    report["checks"]["mohamed_owes_500"] = {
        "http": code,
        "correlationId": corr_debt,
        "sessionId": session_debt,
        "amountMinor": amount,
        "proposals": [
            {
                "tool": p.get("tool"),
                "amountMinor": (p.get("payload") or {}).get("amountMinor"),
                "currencyCode": (p.get("payload") or {}).get("currencyCode"),
                "contactHint": (p.get("payload") or {}).get("contactHint"),
            }
            for p in debt_proposals
            if p.get("tool") == "propose_debt"
        ],
        "pass": ok_debt,
    }
    (OUT_DIR / f"{stamp}_mohamed.json").write_text(
        json.dumps(debt_events, indent=2, ensure_ascii=False)[:500_000],
        encoding="utf-8",
    )
    print(
        f"[4] Mohamed owes 500 HTTP {code} amountMinor={amount!r} pass={ok_debt}"
    )

    # 5) Cloud Logging — model id
    log_cmd = [
        "gcloud",
        "logging",
        "read",
        (
            'resource.type="cloud_run_revision" AND '
            'resource.labels.service_name="daftar-closing-agent" AND '
            f'timestamp>="{datetime.now(timezone.utc).strftime("%Y-%m-%d")}T00:00:00Z" AND '
            'jsonPayload.model_id="gemini-3.5-flash" AND '
            'jsonPayload.event="daftar.agent.model"'
        ),
        f"--project={PROJECT}",
        "--limit=5",
        "--format=json",
    ]
    log_raw = subprocess.check_output(log_cmd, text=True)
    log_entries = json.loads(log_raw) if log_raw.strip() else []
    ok_logs = len(log_entries) > 0 and all(
        (e.get("jsonPayload") or {}).get("model_id") == "gemini-3.5-flash"
        for e in log_entries
    )
    report["checks"]["model_logs"] = {
        "entries": len(log_entries),
        "sample": [
            {
                "event": (e.get("jsonPayload") or {}).get("event"),
                "model_id": (e.get("jsonPayload") or {}).get("model_id"),
                "session_id": (e.get("jsonPayload") or {}).get("session_id"),
                "latency_ms": (e.get("jsonPayload") or {}).get("latency_ms"),
            }
            for e in log_entries[:3]
        ],
        "pass": ok_logs,
    }
    print(f"[5] gemini-3.5-flash logs entries={len(log_entries)} pass={ok_logs}")

    all_pass = all(c.get("pass") for c in report["checks"].values())
    report["pass"] = all_pass
    report_path = OUT_DIR / f"{stamp}_report.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"\nREPORT {report_path} overall_pass={all_pass}")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
