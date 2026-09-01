"""POST /v1/email/send-batch — Appendix J.7 multipart handler."""

from __future__ import annotations

import asyncio
import json
import re
from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError
from starlette.datastructures import UploadFile

from closing_agent.observability import emit_structured
from email_send.c2_body import assemble_c2_body
from email_send.idempotency import EmailIdempotencyStore, InMemoryEmailIdempotencyStore
from email_send.masking import mask_email
from email_send.schemas import (
    MAX_PDF_BYTES,
    MAX_RECIPIENTS,
    EmailRecipient,
    EmailSendBatchManifest,
    EmailSendBatchResponse,
    EmailSendRowResult,
    RowStatus,
)
from email_send.settings import SmtpSettings
from email_send.smtp_client import SmtpSendResult, SmtpSender, StdlibSmtpSender

router = APIRouter(tags=["email-send"])

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")

_default_store = InMemoryEmailIdempotencyStore()
_default_sender = StdlibSmtpSender()


def get_idempotency_store() -> EmailIdempotencyStore:
    return _default_store


def get_smtp_sender() -> SmtpSender:
    return _default_sender


def get_smtp_settings() -> SmtpSettings:
    return SmtpSettings.from_env()


def _row(
    recipient: EmailRecipient,
    *,
    status: RowStatus,
    smtp_message_id: str | None = None,
    smtp_code: int | None = None,
    smtp_message: str | None = None,
) -> EmailSendRowResult:
    return EmailSendRowResult(
        contactId=recipient.contactId,
        toMasked=mask_email(recipient.to.strip()),
        status=status,
        smtpMessageId=smtp_message_id if status == "sent" else None,
        smtpCode=smtp_code,
        smtpMessage=smtp_message,
    )


def _emit_email(
    *,
    correlation_id: str,
    batch_id: str,
    smtp_code: int | None,
    message_id: str | None,
    to_masked: str,
    status: str,
    halt_reason: str | None = None,
) -> None:
    emit_structured(
        "daftar.agent.email",
        message=f"email_row status={status}",
        correlationId=correlation_id,
        batchId=batch_id,
        smtpCode=smtp_code,
        messageId=message_id,
        toMasked=to_masked,
        status=status,
        haltReason=halt_reason,
    )


def _validation_detail(exc: ValidationError) -> str:
    loc = ""
    try:
        err = exc.errors()[0]
        loc = ".".join(str(part) for part in err.get("loc", ()))
        msg = str(err.get("msg", "invalid_manifest"))
        if loc:
            return f"invalid_manifest:{loc}:{msg}"[:200]
        return f"invalid_manifest:{msg}"[:200]
    except Exception:
        return "invalid_manifest"


def _is_valid_email(value: str) -> bool:
    return bool(_EMAIL_RE.match(value))


async def _read_pdfs(form: Any) -> dict[str, bytes]:
    pdfs: dict[str, bytes] = {}
    for key, value in form.multi_items():
        if not isinstance(key, str) or not key.startswith("pdf_"):
            continue
        contact_key = key[4:]
        if not contact_key:
            continue
        if isinstance(value, UploadFile):
            data = await value.read()
            await value.close()
            pdfs[contact_key] = data
        elif isinstance(value, (bytes, bytearray)):
            pdfs[contact_key] = bytes(value)
        elif isinstance(value, str):
            pdfs[contact_key] = value.encode("utf-8")
    return pdfs


def _parse_manifest(raw: str) -> EmailSendBatchManifest:
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="invalid_manifest_json") from exc
    if not isinstance(data, dict):
        raise HTTPException(status_code=400, detail="invalid_manifest_json")
    recipients = data.get("recipients")
    if isinstance(recipients, list) and len(recipients) > MAX_RECIPIENTS:
        raise HTTPException(status_code=400, detail="recipients_cap_exceeded")
    try:
        return EmailSendBatchManifest.model_validate(data)
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=_validation_detail(exc)) from exc


@router.post("/v1/email/send-batch")
async def send_batch(
    request: Request,
    store: Annotated[EmailIdempotencyStore, Depends(get_idempotency_store)],
    sender: Annotated[SmtpSender, Depends(get_smtp_sender)],
    settings: Annotated[SmtpSettings, Depends(get_smtp_settings)],
) -> JSONResponse:
    form = await request.form()
    manifest_field = form.get("manifest")
    if manifest_field is None:
        raise HTTPException(status_code=400, detail="missing_manifest")
    if isinstance(manifest_field, UploadFile):
        manifest_raw = (await manifest_field.read()).decode("utf-8")
        await manifest_field.close()
    else:
        manifest_raw = str(manifest_field)

    manifest = _parse_manifest(manifest_raw)
    pdfs = await _read_pdfs(form)

    batch_id = str(manifest.batchId)
    correlation_id = str(manifest.correlationId)
    results: list[EmailSendRowResult] = []
    needs_human = False
    halt_auth = False
    halt_message = "smtp_auth_rejected"
    smtp_attempted = False
    password: str | None = None

    if not settings.from_equals_user():
        needs_human = True
        halt_auth = True
        halt_message = "from_user_mismatch"
    else:
        try:
            password = settings.load_password()
        except OSError:
            password = ""
        if not password:
            needs_human = True
            halt_auth = True
            halt_message = "smtp_secret_unavailable"

    try:
        for recipient in manifest.recipients:
            to_addr = recipient.to.strip()
            to_masked = mask_email(to_addr)
            contact_key = str(recipient.contactId)

            existing = store.get(batch_id, to_addr) if to_addr else None
            if existing:
                row = _row(
                    recipient,
                    status="skippedDuplicate",
                    smtp_message_id=existing,
                    smtp_message="skipped_duplicate",
                )
                results.append(row)
                _emit_email(
                    correlation_id=correlation_id,
                    batch_id=batch_id,
                    smtp_code=None,
                    message_id=existing,
                    to_masked=to_masked,
                    status="skippedDuplicate",
                )
                continue

            if halt_auth:
                row = _row(
                    recipient,
                    status="failed",
                    smtp_message=halt_message,
                )
                results.append(row)
                _emit_email(
                    correlation_id=correlation_id,
                    batch_id=batch_id,
                    smtp_code=535 if halt_message == "smtp_auth_rejected" else None,
                    message_id=None,
                    to_masked=to_masked,
                    status="failed",
                    halt_reason=halt_message,
                )
                continue

            if not to_addr or not _is_valid_email(to_addr):
                row = _row(
                    recipient,
                    status="failed",
                    smtp_message="invalid_to",
                )
                results.append(row)
                _emit_email(
                    correlation_id=correlation_id,
                    batch_id=batch_id,
                    smtp_code=None,
                    message_id=None,
                    to_masked=to_masked,
                    status="failed",
                    halt_reason="invalid_to",
                )
                continue

            pdf = pdfs.get(contact_key)
            if pdf is not None and len(pdf) == 0:
                pdf = None
            if pdf is not None and len(pdf) > MAX_PDF_BYTES:
                row = _row(
                    recipient,
                    status="failed",
                    smtp_message="pdf_too_large",
                )
                results.append(row)
                _emit_email(
                    correlation_id=correlation_id,
                    batch_id=batch_id,
                    smtp_code=None,
                    message_id=None,
                    to_masked=to_masked,
                    status="failed",
                    halt_reason="pdf_too_large",
                )
                continue

            body = assemble_c2_body(
                locale=manifest.locale,
                customer_name=recipient.customer_name,
                store_name=recipient.store_name,
                amount_line=recipient.amount_line,
                cta_line=recipient.cta_line,
                note=recipient.note,
            )

            if smtp_attempted and settings.stagger_seconds > 0:
                await asyncio.sleep(settings.stagger_seconds)
            smtp_attempted = True

            assert password is not None
            outcome: SmtpSendResult = await asyncio.to_thread(
                sender.send,
                settings=settings,
                password=password,
                from_addr=settings.from_addr,
                to_addr=to_addr,
                subject=recipient.subject,
                body=body,
                pdf_bytes=pdf,
                filename=recipient.filename,
            )

            if outcome.auth_rejected:
                needs_human = True
                halt_auth = True
                halt_message = "smtp_auth_rejected"
                row = _row(
                    recipient,
                    status="failed",
                    smtp_code=outcome.smtp_code or 535,
                    smtp_message=outcome.smtp_message or "smtp_auth_rejected",
                )
                results.append(row)
                _emit_email(
                    correlation_id=correlation_id,
                    batch_id=batch_id,
                    smtp_code=outcome.smtp_code or 535,
                    message_id=None,
                    to_masked=to_masked,
                    status="failed",
                    halt_reason="smtp_auth_rejected",
                )
                continue

            if outcome.ok and outcome.message_id:
                store.put(batch_id, to_addr, outcome.message_id)
                row = _row(
                    recipient,
                    status="sent",
                    smtp_message_id=outcome.message_id,
                    smtp_code=outcome.smtp_code,
                    smtp_message=outcome.smtp_message,
                )
                results.append(row)
                _emit_email(
                    correlation_id=correlation_id,
                    batch_id=batch_id,
                    smtp_code=outcome.smtp_code,
                    message_id=outcome.message_id,
                    to_masked=to_masked,
                    status="sent",
                )
                continue

            row = _row(
                recipient,
                status="failed",
                smtp_code=outcome.smtp_code,
                smtp_message=outcome.smtp_message or "smtp_send_failed",
            )
            results.append(row)
            _emit_email(
                correlation_id=correlation_id,
                batch_id=batch_id,
                smtp_code=outcome.smtp_code,
                message_id=None,
                to_masked=to_masked,
                status="failed",
                halt_reason=outcome.smtp_message or "smtp_send_failed",
            )
    finally:
        if password is not None:
            del password

    payload = EmailSendBatchResponse(
        batchId=manifest.batchId,
        results=results,
        needsHuman=needs_human,
    )
    return JSONResponse(content=payload.model_dump(mode="json"))
