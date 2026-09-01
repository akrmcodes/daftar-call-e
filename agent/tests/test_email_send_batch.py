"""Stage 4.7 send-batch unit tests — mock SMTP, no live Gmail."""

from __future__ import annotations

import io
import json
import uuid
from dataclasses import dataclass, field
from typing import Any

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from email_send.c2_body import C2_BODY_AR, C2_BODY_EN, assemble_c2_body
from email_send.idempotency import InMemoryEmailIdempotencyStore
from email_send.masking import mask_email
from email_send.router import (
    get_idempotency_store,
    get_smtp_sender,
    get_smtp_settings,
    router,
)
from email_send.schemas import MAX_PDF_BYTES
from email_send.settings import DEFAULT_STAGGER_SEC, SmtpSettings
from email_send.smtp_client import (
    SmtpSendResult,
    build_mime_message,
    sanitize_attachment_filename,
)

PDF_MARKER = b"%PDF-MARKER-DO-NOT-LOG-XYZ"
PASSWORD = "smtp-app-password-UNIQUE-SECRET-XYZ"
SENDER_MAILBOX = "sender@example.com"


def _tiny_pdf() -> bytes:
    return b"%PDF-1.4\n" + PDF_MARKER + b"\n%%EOF\n"


def _fill(template: str, **params: str) -> str:
    out = template
    for key, value in params.items():
        out = out.replace("{{" + key + "}}", value)
    return out


@dataclass
class RecordingSender:
    calls: list[dict[str, Any]] = field(default_factory=list)
    auth_fail_at: int | None = None

    def send(
        self,
        *,
        settings: SmtpSettings,
        password: str,
        from_addr: str,
        to_addr: str,
        subject: str,
        body: str,
        pdf_bytes: bytes | None,
        filename: str | None,
    ) -> SmtpSendResult:
        msg = build_mime_message(
            from_addr=from_addr,
            to_addr=to_addr,
            subject=subject,
            body=body,
            pdf_bytes=pdf_bytes,
            filename=filename,
        )
        mid = str(msg["Message-ID"])
        to_header = msg.get("To")
        self.calls.append(
            {
                "from_addr": from_addr,
                "to_addr": to_addr,
                "to_header": to_header,
                "subject": subject,
                "body": body,
                "filename": filename,
                "pdf_len": 0 if not pdf_bytes else len(pdf_bytes),
                "message_id": mid,
                "user": settings.user,
                "has_password": bool(password),
            }
        )
        if self.auth_fail_at is not None and len(self.calls) > self.auth_fail_at:
            return SmtpSendResult(
                ok=False,
                smtp_code=535,
                smtp_message="Username and Password not accepted",
                message_id=None,
                auth_rejected=True,
                from_addr=from_addr,
                to_addrs=(to_addr,),
            )
        return SmtpSendResult(
            ok=True,
            smtp_code=250,
            smtp_message="2.0.0 OK",
            message_id=mid,
            from_addr=from_addr,
            to_addrs=(to_addr,),
        )


def _recipient(**overrides: Any) -> dict[str, Any]:
    row = {
        "contactId": str(uuid.uuid4()),
        "to": "customer@example.com",
        "subject": "Al-Ghanem Store: outstanding balance 500 YER",
        "customer_name": "Mohamed Ali",
        "store_name": "Al-Ghanem Store",
        "amount_line": "500 YER",
        "cta_line": "Please arrange payment when you can.",
        "note": "",
        "filename": "daftar-mohamed.pdf",
    }
    row.update(overrides)
    return row


def _app(
    monkeypatch: Any,
    tmp_path: Any,
    sender: RecordingSender,
    store: InMemoryEmailIdempotencyStore | None = None,
    *,
    from_addr: str = SENDER_MAILBOX,
    user: str = SENDER_MAILBOX,
) -> tuple[TestClient, InMemoryEmailIdempotencyStore]:
    secret = tmp_path / "gmail-smtp-app-password"
    secret.write_text(PASSWORD + "\n", encoding="utf-8")
    monkeypatch.setenv("GMAIL_SMTP_USER", user)
    monkeypatch.setenv("GMAIL_SMTP_FROM", from_addr)
    monkeypatch.setenv("GMAIL_SMTP_HOST", "smtp.gmail.com")
    monkeypatch.setenv("GMAIL_SMTP_PORT", "587")
    monkeypatch.setenv("GMAIL_SMTP_PASSWORD_FILE", str(secret))
    monkeypatch.setenv("GMAIL_SMTP_STAGGER_SEC", "0")
    store = store or InMemoryEmailIdempotencyStore()
    app = FastAPI()
    app.include_router(router)
    app.dependency_overrides[get_idempotency_store] = lambda: store
    app.dependency_overrides[get_smtp_sender] = lambda: sender
    app.dependency_overrides[get_smtp_settings] = lambda: SmtpSettings.from_env()
    return TestClient(app), store


def _post(
    client: TestClient,
    recipients: list[dict[str, Any]],
    pdfs: dict[str, bytes],
    *,
    locale: str = "en",
    batch_id: str | None = None,
    extra_manifest: dict[str, Any] | None = None,
) -> Any:
    batch_id = batch_id or str(uuid.uuid4())
    manifest: dict[str, Any] = {
        "batchId": batch_id,
        "correlationId": str(uuid.uuid4()),
        "locale": locale,
        "recipients": recipients,
    }
    if extra_manifest:
        manifest.update(extra_manifest)
    files = [
        (f"pdf_{cid}", (f"{cid}.pdf", data, "application/pdf"))
        for cid, data in pdfs.items()
    ]
    return client.post(
        "/v1/email/send-batch",
        data={"manifest": json.dumps(manifest)},
        files=files or None,
    ), batch_id


def test_c2_en_fixture() -> None:
    params = {
        "customer_name": "Mohamed Ali",
        "store_name": "Al-Ghanem Store",
        "amount_line": "500 YER",
        "cta_line": "Please arrange payment when you can.",
        "note": "",
    }
    assert assemble_c2_body(locale="en", **params) == _fill(C2_BODY_EN, **params)


def test_c2_ar_fixture() -> None:
    params = {
        "customer_name": "محمد علي",
        "store_name": "محل الغانم",
        "amount_line": "500 ر.ي",
        "cta_line": "نرجو ترتيب السداد عند التمكّن.",
        "note": "",
    }
    assert assemble_c2_body(locale="ar", **params) == _fill(C2_BODY_AR, **params)


def test_mask_email_last4_and_short() -> None:
    assert mask_email("akrm.codes@gmail.com") == "***odes@gmail.com"
    assert mask_email("ab@x.test") == "a***@x.test"


def test_sanitize_filename_strips_path() -> None:
    assert sanitize_attachment_filename("../../evil name.pdf") == "daftar-evil_name.pdf"
    assert sanitize_attachment_filename("daftar-mohamed.pdf") == "daftar-mohamed.pdf"


def test_unique_message_id_and_single_to() -> None:
    a = build_mime_message(
        from_addr=SENDER_MAILBOX,
        to_addr="one@example.com",
        subject="s",
        body="b",
        pdf_bytes=_tiny_pdf(),
        filename="a.pdf",
    )
    b = build_mime_message(
        from_addr=SENDER_MAILBOX,
        to_addr="two@example.com",
        subject="s",
        body="b",
        pdf_bytes=_tiny_pdf(),
        filename="b.pdf",
    )
    assert a["From"] == SENDER_MAILBOX
    assert a["To"] == "one@example.com"
    assert b["To"] == "two@example.com"
    assert a["Message-ID"] != b["Message-ID"]
    assert a.get_content_type() == "multipart/mixed"


def test_text_only_mime_is_plain() -> None:
    msg = build_mime_message(
        from_addr=SENDER_MAILBOX,
        to_addr="one@example.com",
        subject="s",
        body="b",
        pdf_bytes=None,
        filename=None,
    )
    assert msg.get_content_type() == "text/plain"
    assert msg["To"] == "one@example.com"


def test_cap_twenty_one_returns_400(monkeypatch: Any, tmp_path: Any) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    recipients = [_recipient(to=f"r{i}@example.com") for i in range(21)]
    resp, _ = _post(client, recipients, {})
    assert resp.status_code == 400
    assert sender.calls == []
    assert "recipients_cap_exceeded" in resp.text


def test_cap_twenty_accepted_text_only(monkeypatch: Any, tmp_path: Any) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    recipients = [_recipient(to=f"r{i}@example.com") for i in range(20)]
    resp, _ = _post(client, recipients, {})
    assert resp.status_code == 200
    assert len(sender.calls) == 20
    assert all(call["pdf_len"] == 0 for call in sender.calls)
    assert all(row["status"] == "sent" for row in resp.json()["results"])


def test_send_batch_unique_ids_from_equals_user_one_to(
    monkeypatch: Any, tmp_path: Any
) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    r1 = _recipient(to="one@example.com")
    r2 = _recipient(to="two@example.com")
    pdfs = {
        r1["contactId"]: _tiny_pdf(),
        r2["contactId"]: _tiny_pdf(),
    }
    resp, batch_id = _post(client, [r1, r2], pdfs)
    assert resp.status_code == 200
    body = resp.json()
    assert body["batchId"] == batch_id
    assert body["needsHuman"] is False
    assert [row["status"] for row in body["results"]] == ["sent", "sent"]
    ids = [row["smtpMessageId"] for row in body["results"]]
    assert ids[0] and ids[1] and ids[0] != ids[1]
    assert all(row["smtpCode"] == 250 for row in body["results"])
    assert len(sender.calls) == 2
    assert sender.calls[0]["from_addr"] == SENDER_MAILBOX
    assert sender.calls[0]["user"] == SENDER_MAILBOX
    assert sender.calls[0]["from_addr"] == sender.calls[0]["user"]
    assert sender.calls[0]["to_addr"] == "one@example.com"
    assert sender.calls[1]["to_addr"] == "two@example.com"
    assert sender.calls[0]["to_header"] == "one@example.com"
    assert "," not in sender.calls[0]["to_header"]


def test_idempotency_skips_second_smtp(monkeypatch: Any, tmp_path: Any) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    rec = _recipient(to="same@example.com")
    pdfs = {rec["contactId"]: _tiny_pdf()}
    resp1, batch_id = _post(client, [rec], pdfs)
    assert resp1.json()["results"][0]["status"] == "sent"
    resp2, _ = _post(client, [rec], pdfs, batch_id=batch_id)
    assert resp2.status_code == 200
    assert resp2.json()["results"][0]["status"] == "skippedDuplicate"
    assert len(sender.calls) == 1


def test_pdf_over_5mb_row_failed_no_smtp(monkeypatch: Any, tmp_path: Any) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    rec = _recipient()
    huge = b"%PDF-1.4\n" + (b"x" * (MAX_PDF_BYTES + 1))
    resp, _ = _post(client, [rec], {rec["contactId"]: huge})
    assert resp.status_code == 200
    row = resp.json()["results"][0]
    assert row["status"] == "failed"
    assert row["smtpMessage"] == "pdf_too_large"
    assert row["smtpMessageId"] is None
    assert sender.calls == []


def test_missing_pdf_is_text_only_sent(monkeypatch: Any, tmp_path: Any) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    rec = _recipient()
    rec.pop("filename", None)
    resp, _ = _post(client, [rec], {})
    assert resp.status_code == 200
    row = resp.json()["results"][0]
    assert row["status"] == "sent"
    assert row["smtpCode"] == 250
    assert sender.calls[-1]["pdf_len"] == 0


def test_invalid_to_fails_row_others_may_send(monkeypatch: Any, tmp_path: Any) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    bad = _recipient(to="not-an-email")
    good = _recipient(to="ok@example.com")
    pdfs = {bad["contactId"]: _tiny_pdf(), good["contactId"]: _tiny_pdf()}
    resp, _ = _post(client, [bad, good], pdfs)
    body = resp.json()
    assert body["results"][0]["status"] == "failed"
    assert body["results"][0]["smtpMessage"] == "invalid_to"
    assert body["results"][1]["status"] == "sent"
    assert len(sender.calls) == 1


def test_secret_not_in_logs_or_response(
    monkeypatch: Any, tmp_path: Any
) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    buf = io.StringIO()
    monkeypatch.setattr("closing_agent.observability.sys.stdout", buf)
    rec = _recipient(to="visible.part@example.com")
    resp, _ = _post(client, [rec], {rec["contactId"]: _tiny_pdf()})
    dumped = json.dumps(resp.json()) + buf.getvalue()
    assert PASSWORD not in dumped
    assert PDF_MARKER.decode("ascii") not in dumped
    assert "visible.part@example.com" not in dumped
    assert resp.json()["results"][0]["toMasked"] == "***part@example.com"


def test_c2_en_ar_bodies_on_smtp(monkeypatch: Any, tmp_path: Any) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    en = _recipient()
    resp, _ = _post(client, [en], {en["contactId"]: _tiny_pdf()}, locale="en")
    assert resp.status_code == 200
    assert sender.calls[-1]["body"] == assemble_c2_body(
        locale="en",
        customer_name="Mohamed Ali",
        store_name="Al-Ghanem Store",
        amount_line="500 YER",
        cta_line="Please arrange payment when you can.",
        note="",
    )
    ar = _recipient(
        to="ar@example.com",
        customer_name="محمد علي",
        store_name="محل الغانم",
        amount_line="500 ر.ي",
        cta_line="نرجو ترتيب السداد عند التمكّن.",
        subject="محل الغانم: رصيد مستحق 500 ر.ي",
    )
    resp_ar, _ = _post(
        client, [ar], {ar["contactId"]: _tiny_pdf()}, locale="ar"
    )
    assert resp_ar.status_code == 200
    assert sender.calls[-1]["body"] == assemble_c2_body(
        locale="ar",
        customer_name="محمد علي",
        store_name="محل الغانم",
        amount_line="500 ر.ي",
        cta_line="نرجو ترتيب السداد عند التمكّن.",
        note="",
    )


def test_535_needs_human_stops_remaining_smtp(
    monkeypatch: Any, tmp_path: Any, capsys: Any
) -> None:
    sender = RecordingSender(auth_fail_at=0)
    client, _ = _app(monkeypatch, tmp_path, sender)
    r1 = _recipient(to="first@example.com")
    r2 = _recipient(to="second@example.com")
    pdfs = {r1["contactId"]: _tiny_pdf(), r2["contactId"]: _tiny_pdf()}
    resp, _ = _post(client, [r1, r2], pdfs)
    body = resp.json()
    assert body["needsHuman"] is True
    assert body["results"][0]["status"] == "failed"
    assert body["results"][0]["smtpCode"] == 535
    assert body["results"][1]["status"] == "failed"
    assert len(sender.calls) == 1
    assert PASSWORD not in json.dumps(body)
    logs = [
        json.loads(line)
        for line in capsys.readouterr().out.splitlines()
        if line.startswith("{")
    ]
    email_logs = [row for row in logs if row.get("event") == "daftar.agent.email"]
    assert email_logs[0]["haltReason"] == "smtp_auth_rejected"


def test_from_user_mismatch_fail_closed(
    monkeypatch: Any, tmp_path: Any, capsys: Any
) -> None:
    sender = RecordingSender()
    client, _ = _app(
        monkeypatch,
        tmp_path,
        sender,
        from_addr="other@example.com",
        user=SENDER_MAILBOX,
    )
    rec = _recipient()
    resp, _ = _post(client, [rec], {rec["contactId"]: _tiny_pdf()})
    body = resp.json()
    assert body["needsHuman"] is True
    assert body["results"][0]["status"] == "failed"
    assert body["results"][0]["smtpMessage"] == "from_user_mismatch"
    assert sender.calls == []
    logs = [
        json.loads(line)
        for line in capsys.readouterr().out.splitlines()
        if line.startswith("{")
    ]
    email_logs = [row for row in logs if row.get("event") == "daftar.agent.email"]
    assert email_logs
    assert email_logs[0]["haltReason"] == "from_user_mismatch"


def test_empty_sender_env_is_from_user_mismatch(
    monkeypatch: Any, tmp_path: Any, capsys: Any
) -> None:
    sender = RecordingSender()
    client, _ = _app(
        monkeypatch,
        tmp_path,
        sender,
        from_addr="",
        user="",
    )
    rec = _recipient()
    resp, _ = _post(client, [rec], {rec["contactId"]: _tiny_pdf()})
    body = resp.json()
    assert body["needsHuman"] is True
    assert body["results"][0]["smtpMessage"] == "from_user_mismatch"
    assert sender.calls == []
    logs = [
        json.loads(line)
        for line in capsys.readouterr().out.splitlines()
        if line.startswith("{")
    ]
    email_logs = [row for row in logs if row.get("event") == "daftar.agent.email"]
    assert email_logs[0]["haltReason"] == "from_user_mismatch"


def test_secret_unavailable_logs_halt_reason(
    monkeypatch: Any, tmp_path: Any, capsys: Any
) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    monkeypatch.setenv(
        "GMAIL_SMTP_PASSWORD_FILE", str(tmp_path / "missing-gmail-secret")
    )
    rec = _recipient()
    resp, _ = _post(client, [rec], {rec["contactId"]: _tiny_pdf()})
    body = resp.json()
    assert body["needsHuman"] is True
    assert body["results"][0]["smtpMessage"] == "smtp_secret_unavailable"
    assert sender.calls == []
    logs = [
        json.loads(line)
        for line in capsys.readouterr().out.splitlines()
        if line.startswith("{")
    ]
    email_logs = [row for row in logs if row.get("event") == "daftar.agent.email"]
    assert email_logs[0]["haltReason"] == "smtp_secret_unavailable"


def test_amount_minor_and_body_rejected(monkeypatch: Any, tmp_path: Any) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    rec = _recipient()
    rec["amountMinor"] = 500
    resp, _ = _post(client, [rec], {rec["contactId"]: _tiny_pdf()})
    assert resp.status_code == 400
    rec2 = _recipient()
    rec2["body"] = "llm freeform"
    resp2, _ = _post(client, [rec2], {rec2["contactId"]: _tiny_pdf()})
    assert resp2.status_code == 400
    assert sender.calls == []


def test_invalid_locale_400(monkeypatch: Any, tmp_path: Any) -> None:
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    rec = _recipient()
    resp, _ = _post(
        client, [rec], {rec["contactId"]: _tiny_pdf()}, locale="fr"
    )
    assert resp.status_code == 400
    assert sender.calls == []


def test_stagger_sleeps_between_smtp_attempts(
    monkeypatch: Any, tmp_path: Any
) -> None:
    assert DEFAULT_STAGGER_SEC == 1.0
    sender = RecordingSender()
    client, _ = _app(monkeypatch, tmp_path, sender)
    monkeypatch.setenv("GMAIL_SMTP_STAGGER_SEC", "1.0")
    slept: list[float] = []

    async def fake_sleep(delay: float, *args: Any, **kwargs: Any) -> None:
        slept.append(delay)

    monkeypatch.setattr("email_send.router.asyncio.sleep", fake_sleep)

    first = _recipient(to="one@example.com")
    second = _recipient(to="two@example.com")
    first.pop("filename", None)
    second.pop("filename", None)
    resp, _ = _post(client, [first, second], {})
    assert resp.status_code == 200
    assert [row["status"] for row in resp.json()["results"]] == ["sent", "sent"]
    assert len(sender.calls) == 2
    assert slept == [1.0]


def test_boot_log_misconfigured(monkeypatch: Any, capsys: Any) -> None:
    monkeypatch.setenv("GMAIL_SMTP_USER", "")
    monkeypatch.setenv("GMAIL_SMTP_FROM", "other@example.com")
    from email_send.settings import log_smtp_boot_config

    log_smtp_boot_config()
    logs = [
        json.loads(line)
        for line in capsys.readouterr().out.splitlines()
        if line.startswith("{")
    ]
    config_logs = [
        row for row in logs if row.get("event") == "daftar.agent.email_config"
    ]
    assert config_logs
    assert config_logs[0]["message"] == "gmail_sender_misconfigured"
    assert config_logs[0]["fromEqualsUser"] is False
    assert config_logs[0]["severity"] == "ERROR"
