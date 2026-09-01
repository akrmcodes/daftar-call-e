#!/usr/bin/env python3
"""Stage 4.6 local Gmail SMTP smoke — STARTTLS 587 + tiny PDF.

Reads the App Password from Secret Manager via gcloud (never argv, never a file).
Requires env: GMAIL_SMTP_USER, GMAIL_SMTP_FROM (same address), GMAIL_SMTP_TO.
Writes evidence JSON under agent/smoke_evidence/ (gitignored).
Does not print the App Password, full recipient, or PDF bytes.
"""

from __future__ import annotations

import json
import os
import smtplib
import ssl
import subprocess
import sys
import uuid
from datetime import datetime, timezone
from email.message import EmailMessage
from email.utils import make_msgid
from pathlib import Path

PROJECT = "daftar-closing-agent"
SECRET = "gmail-smtp-app-password"
HOST = "smtp.gmail.com"
PORT = 587
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
    stream = b"BT /F1 12 Tf 20 40 Td (Daftar SMTP smoke) Tj ET\n"
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


def _app_password() -> str:
    raw = subprocess.check_output(
        [
            "gcloud",
            "secrets",
            "versions",
            "access",
            "latest",
            f"--secret={SECRET}",
            f"--project={PROJECT}",
        ],
        text=True,
    )
    password = raw.strip()
    if not password:
        raise SystemExit("empty secret payload")
    return password


class _Smtp(smtplib.SMTP):
    last_data: tuple[int, bytes] | None = None

    def data(self, msg: str | bytes) -> tuple[int, bytes]:
        code, resp = super().data(msg)
        self.last_data = (code, resp)
        return code, resp


def main() -> int:
    user = _require_env("GMAIL_SMTP_USER")
    from_addr = _require_env("GMAIL_SMTP_FROM")
    to_addr = _require_env("GMAIL_SMTP_TO")
    if user != from_addr:
        raise SystemExit("GMAIL_SMTP_USER and GMAIL_SMTP_FROM must be the same address")

    message_id = make_msgid(idstring=uuid.uuid4().hex, domain="gmail.com")
    pdf = _tiny_pdf()

    msg = EmailMessage()
    msg["From"] = from_addr
    msg["To"] = to_addr
    msg["Subject"] = "Daftar §4.6 SMTP smoke"
    msg["Message-ID"] = message_id
    msg.set_content(
        "Daftar closing-agent §4.6 Gmail SMTP smoke.\n"
        "Tiny PDF attached. Unique Message-ID on this message.\n"
    )
    msg.add_attachment(
        pdf,
        maintype="application",
        subtype="pdf",
        filename="daftar-smoke.pdf",
    )

    password = _app_password()
    smtp_code: int | None = None
    smtp_reply = ""
    try:
        context = ssl.create_default_context()
        with _Smtp(HOST, PORT, timeout=45) as smtp:
            smtp.ehlo()
            smtp.starttls(context=context)
            smtp.ehlo()
            smtp.login(user, password)
            smtp.send_message(msg)
            if smtp.last_data is None:
                raise RuntimeError("SMTP DATA reply missing")
            smtp_code, raw_reply = smtp.last_data
            smtp_reply = raw_reply.decode("utf-8", errors="replace").strip()
    finally:
        del password

    ok = smtp_code == 250
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    report = {
        "stage": "4.6",
        "host": HOST,
        "port": PORT,
        "starttls": True,
        "smtpCode": smtp_code,
        "smtpReplySafe": smtp_reply[:200],
        "messageId": message_id,
        "toMasked": _mask_email(to_addr),
        "filename": "daftar-smoke.pdf",
        "pdfBytes": len(pdf),
        "pass": ok,
    }
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    report_path = OUT_DIR / f"{stamp}_smtp_smoke.json"
    report_path.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(
        f"smtpCode={smtp_code} messageId={message_id} "
        f"toMasked={report['toMasked']} pass={ok} report={report_path}"
    )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
