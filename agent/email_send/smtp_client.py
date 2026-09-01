"""Stdlib Gmail SMTP MIME client — EmailMessage + smtplib. No Secret Manager SDK."""

from __future__ import annotations

import re
import ssl
import uuid
from dataclasses import dataclass
from email.message import EmailMessage
from email.utils import make_msgid
from pathlib import Path
from typing import Protocol

import smtplib

from email_send.settings import SmtpSettings

_UNSAFE_FILENAME = re.compile(r"[^A-Za-z0-9._-]+")


def sanitize_attachment_filename(raw: str) -> str:
    """Basename only → ``daftar-{sanitized}.pdf``. Never a path."""
    name = Path(str(raw).replace("\\", "/")).name
    stem = name[:-4] if name.lower().endswith(".pdf") else name
    if stem.lower().startswith("daftar-"):
        stem = stem[7:]
    cleaned = _UNSAFE_FILENAME.sub("_", stem).strip("._-")
    if not cleaned:
        cleaned = "statement"
    return f"daftar-{cleaned[:64]}.pdf"


def safe_smtp_text(text: str, password: str | None = None) -> str:
    cleaned = text.replace("\r", " ").replace("\n", " ").strip()[:200]
    if password:
        cleaned = cleaned.replace(password, "***")
    return cleaned


def build_mime_message(
    *,
    from_addr: str,
    to_addr: str,
    subject: str,
    body: str,
    pdf_bytes: bytes | None = None,
    filename: str | None = None,
    message_id: str | None = None,
) -> EmailMessage:
    """One From, one To, unique Message-ID. PDF attachment only when bytes present."""
    mid = message_id or make_msgid(idstring=uuid.uuid4().hex, domain="gmail.com")
    msg = EmailMessage()
    msg["From"] = from_addr
    msg["To"] = to_addr
    msg["Subject"] = subject
    msg["Message-ID"] = mid
    msg.set_content(body, subtype="plain", charset="utf-8")
    if pdf_bytes:
        msg.add_attachment(
            pdf_bytes,
            maintype="application",
            subtype="pdf",
            filename=sanitize_attachment_filename(filename or "statement"),
        )
    return msg


class _Smtp(smtplib.SMTP):
    last_data: tuple[int, bytes] | None = None

    def data(self, msg: str | bytes) -> tuple[int, bytes]:
        code, resp = super().data(msg)
        self.last_data = (code, resp)
        return code, resp


class _SmtpSSL(smtplib.SMTP_SSL):
    last_data: tuple[int, bytes] | None = None

    def data(self, msg: str | bytes) -> tuple[int, bytes]:
        code, resp = super().data(msg)
        self.last_data = (code, resp)
        return code, resp


@dataclass(frozen=True)
class SmtpSendResult:
    ok: bool
    smtp_code: int | None
    smtp_message: str
    message_id: str | None
    auth_rejected: bool = False
    from_addr: str = ""
    to_addrs: tuple[str, ...] = ()


class SmtpSender(Protocol):
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
    ) -> SmtpSendResult: ...


def _auth_rejected(exc: BaseException) -> bool:
    if isinstance(exc, smtplib.SMTPAuthenticationError):
        return True
    code = getattr(exc, "smtp_code", None)
    return code == 535


def _result_from_exc(
    exc: BaseException,
    *,
    password: str,
    from_addr: str,
    to_addr: str,
    message_id: str,
) -> SmtpSendResult:
    code = getattr(exc, "smtp_code", None)
    if not isinstance(code, int):
        code = None
    raw = getattr(exc, "smtp_error", None)
    if isinstance(raw, bytes):
        text = raw.decode("utf-8", errors="replace")
    elif isinstance(raw, str):
        text = raw
    else:
        text = str(exc)
    return SmtpSendResult(
        ok=False,
        smtp_code=code,
        smtp_message=safe_smtp_text(text, password),
        message_id=None,
        auth_rejected=_auth_rejected(exc),
        from_addr=from_addr,
        to_addrs=(to_addr,),
    )


def _finish_send(
    smtp: _Smtp | _SmtpSSL,
    msg: EmailMessage,
    *,
    password: str,
    from_addr: str,
    to_addr: str,
) -> SmtpSendResult:
    smtp.send_message(msg)
    if smtp.last_data is None:
        return SmtpSendResult(
            ok=False,
            smtp_code=None,
            smtp_message="smtp_data_reply_missing",
            message_id=None,
            from_addr=from_addr,
            to_addrs=(to_addr,),
        )
    code, raw_reply = smtp.last_data
    text = raw_reply.decode("utf-8", errors="replace")
    mid = str(msg["Message-ID"] or "")
    ok = code == 250 and bool(mid)
    return SmtpSendResult(
        ok=ok,
        smtp_code=code,
        smtp_message=safe_smtp_text(text, password),
        message_id=mid if ok else None,
        from_addr=from_addr,
        to_addrs=(to_addr,),
    )


class StdlibSmtpSender:
    """STARTTLS 587 first; SMTP_SSL 465 only if connect/STARTTLS fails (not 535)."""

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
        context = ssl.create_default_context()
        logged_in = False
        try:
            with _Smtp(settings.host, 587, timeout=45) as smtp:
                smtp.ehlo()
                smtp.starttls(context=context)
                smtp.ehlo()
                smtp.login(settings.user, password)
                logged_in = True
                return _finish_send(
                    smtp,
                    msg,
                    password=password,
                    from_addr=from_addr,
                    to_addr=to_addr,
                )
        except smtplib.SMTPAuthenticationError as exc:
            return _result_from_exc(
                exc,
                password=password,
                from_addr=from_addr,
                to_addr=to_addr,
                message_id=str(msg["Message-ID"] or ""),
            )
        except Exception as exc:
            if logged_in or _auth_rejected(exc):
                return _result_from_exc(
                    exc,
                    password=password,
                    from_addr=from_addr,
                    to_addr=to_addr,
                    message_id=str(msg["Message-ID"] or ""),
                )
            try:
                with _SmtpSSL(
                    settings.host, 465, timeout=45, context=context
                ) as smtp:
                    smtp.ehlo()
                    smtp.login(settings.user, password)
                    return _finish_send(
                        smtp,
                        msg,
                        password=password,
                        from_addr=from_addr,
                        to_addr=to_addr,
                    )
            except Exception as exc2:
                return _result_from_exc(
                    exc2,
                    password=password,
                    from_addr=from_addr,
                    to_addr=to_addr,
                    message_id=str(msg["Message-ID"] or ""),
                )
