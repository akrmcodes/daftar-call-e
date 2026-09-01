#!/usr/bin/env python3
"""Stage 4.7 live send-batch smoke — authenticated Cloud Run + tiny PDF.

Requires env: GMAIL_SMTP_TO (owned inbox). Uses gcloud identity token.
Writes gitignored evidence under agent/smoke_evidence/.
Does not print the App Password, full recipient, or PDF bytes.
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

SERVICE_URL = "https://daftar-closing-agent-1487285471.us-central1.run.app"
PROJECT = "daftar-closing-agent"
OUT_DIR = Path(__file__).resolve().parents[1] / "smoke_evidence"


def _require_env(name: str) -> str:
    value = os.environ.get(name, "").strip()
    if not value:
        raise SystemExit(f"missing env {name}")
    return value


def _mask_email(address: str) -> str:
    local, _, domain = address.partition("@")
    if not domain:
        return "***"
    if len(local) >= 4:
        return f"***{local[-4:]}@{domain}"
    return f"{local[:1]}***@{domain}"


def _tiny_pdf() -> bytes:
    stream = b"BT /F1 12 Tf 20 40 Td (Daftar send-batch smoke) Tj ET\n"
    objects = [
        b"1 0 obj<< /Type /Catalog /Pages 2 0 R >>endobj\n",
        b"2 0 obj<< /Type /Pages /Kids [3 0 R] /Count 1 >>endobj\n",
        (
            b"3 0 obj<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 144] "
            b"/Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>endobj\n"
        ),
        b"4 0 obj<< /Length "
        + str(len(stream)).encode("ascii")
        + b" >>stream\n"
        + stream
        + b"endstream\nendobj\n",
        b"5 0 obj<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>endobj\n",
    ]
    header = b"%PDF-1.4\n"
    body = header
    offsets = [0]
    for obj in objects:
        offsets.append(len(body))
        body += obj
    xref_start = len(body)
    xref = b"xref\n0 6\n0000000000 65535 f \n"
    for off in offsets[1:]:
        xref += f"{off:010d} 00000 n \n".encode("ascii")
    trailer = (
        b"trailer<< /Size 6 /Root 1 0 R >>\n"
        + f"startxref\n{xref_start}\n".encode("ascii")
        + b"%%EOF\n"
    )
    return body + xref + trailer


def identity_token() -> str:
    return subprocess.check_output(
        ["gcloud", "auth", "print-identity-token"],
        text=True,
    ).strip()


def _multipart(fields: dict[str, str], files: dict[str, tuple[str, bytes, str]]) -> tuple[bytes, str]:
    boundary = f"----daftar{uuid.uuid4().hex}"
    chunks: list[bytes] = []
    for name, value in fields.items():
        chunks.append(
            (
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
                f"{value}\r\n"
            ).encode("utf-8")
        )
    for name, (filename, data, content_type) in files.items():
        chunks.append(
            (
                f"--{boundary}\r\n"
                f'Content-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'
                f"Content-Type: {content_type}\r\n\r\n"
            ).encode("utf-8")
        )
        chunks.append(data)
        chunks.append(b"\r\n")
    chunks.append(f"--{boundary}--\r\n".encode("ascii"))
    return b"".join(chunks), boundary


def main() -> int:
    to_addr = _require_env("GMAIL_SMTP_TO")
    contact_id = str(uuid.uuid4())
    batch_id = str(uuid.uuid4())
    correlation_id = str(uuid.uuid4())
    pdf = _tiny_pdf()
    manifest = {
        "batchId": batch_id,
        "correlationId": correlation_id,
        "locale": "en",
        "recipients": [
            {
                "contactId": contact_id,
                "to": to_addr,
                "subject": "Daftar: outstanding balance 500 YER",
                "customer_name": "Mohamed Ali",
                "store_name": "Daftar",
                "amount_line": "500 YER",
                "cta_line": "Please arrange payment when you can.",
                "note": "",
                "filename": "daftar-smoke.pdf",
            }
        ],
    }
    body, boundary = _multipart(
        {"manifest": json.dumps(manifest)},
        {f"pdf_{contact_id}": ("daftar-smoke.pdf", pdf, "application/pdf")},
    )
    token = identity_token()
    req = Request(
        f"{SERVICE_URL}/v1/email/send-batch",
        data=body,
        method="POST",
    )
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Content-Type", f"multipart/form-data; boundary={boundary}")

    status = 0
    payload: Any = None
    try:
        with urlopen(req, timeout=180) as resp:
            status = resp.status
            raw = resp.read().decode("utf-8")
            payload = json.loads(raw) if raw.strip() else None
    except HTTPError as exc:
        status = exc.code
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = raw
    except URLError as exc:
        raise SystemExit(f"request failed: {exc}") from exc

    row: dict[str, Any] = {}
    if isinstance(payload, dict) and isinstance(payload.get("results"), list) and payload["results"]:
        first = payload["results"][0]
        if isinstance(first, dict):
            row = first

    ok = (
        status == 200
        and isinstance(payload, dict)
        and row.get("status") == "sent"
        and row.get("smtpCode") == 250
        and bool(row.get("smtpMessageId"))
        and payload.get("needsHuman") is False
    )

    log_event: Any = None
    log_ok = False
    for attempt in range(1, 7):
        try:
            raw_logs = subprocess.check_output(
                [
                    "gcloud",
                    "logging",
                    "read",
                    'resource.type="cloud_run_revision" AND '
                    'resource.labels.service_name="daftar-closing-agent" AND '
                    'jsonPayload.event="daftar.agent.email"',
                    f"--project={PROJECT}",
                    "--limit=5",
                    "--freshness=15m",
                    "--format=json",
                ],
                text=True,
            )
            entries = json.loads(raw_logs) if raw_logs.strip() else []
            if isinstance(entries, list) and entries:
                payload_log = entries[0].get("jsonPayload") or {}
                log_event = payload_log.get("event")
                log_ok = log_event == "daftar.agent.email"
                log_blob = json.dumps(payload_log)
                if to_addr in log_blob:
                    log_ok = False
                    log_event = "leaked_full_to"
                if log_ok:
                    break
        except subprocess.CalledProcessError as exc:
            log_event = f"logging_read_failed:{exc.returncode}"
        if attempt < 6:
            time.sleep(5)

    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    report = {
        "stage": "4.7",
        "http": status,
        "batchId": batch_id,
        "correlationId": correlation_id,
        "toMasked": _mask_email(to_addr),
        "status": row.get("status"),
        "smtpCode": row.get("smtpCode"),
        "smtpMessageId": row.get("smtpMessageId"),
        "needsHuman": payload.get("needsHuman") if isinstance(payload, dict) else None,
        "logEvent": log_event,
        "logOk": log_ok,
        "pdfBytes": len(pdf),
        "pass": ok and log_ok,
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report_path = OUT_DIR / f"{stamp}_send_batch.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(
        f"http={status} status={row.get('status')} smtpCode={row.get('smtpCode')} "
        f"smtpMessageId={row.get('smtpMessageId')} toMasked={report['toMasked']} "
        f"needsHuman={report['needsHuman']} logOk={log_ok} pass={report['pass']} "
        f"report={report_path}"
    )
    return 0 if report["pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
