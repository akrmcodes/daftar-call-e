"""POST /v1/calls/plan-batch — Daftar-local gates. Zero PSTN. Zero Developer API."""

from __future__ import annotations

from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from closing_agent.observability import emit_structured
from calls.handles import (
    ConfirmHandleStore,
    InMemoryConfirmHandleStore,
    new_confirm_handle,
)
from calls.j10 import is_valid_e164, region_gate
from calls.masking import mask_e164
from calls.schemas import (
    MAX_RECIPIENTS,
    CallRecipient,
    PlanBatchRequest,
    PlanBatchResponse,
    PlanBatchRowResult,
    RejectReason,
)
from calls.settings import CallSettings

router = APIRouter(tags=["calls"])

_default_store = InMemoryConfirmHandleStore()


def get_call_settings() -> CallSettings:
    return CallSettings.from_env()


def get_handle_store() -> ConfirmHandleStore:
    return _default_store


def _validation_detail(exc: ValidationError) -> str:
    try:
        err = exc.errors()[0]
        loc = ".".join(str(part) for part in err.get("loc", ()))
        msg = str(err.get("msg", "invalid_request"))
        if loc:
            return f"invalid_request:{loc}:{msg}"[:200]
        return f"invalid_request:{msg}"[:200]
    except Exception:
        return "invalid_request"


def _emit_plan(
    *,
    correlation_id: str,
    batch_id: str,
    status: str,
    phone_masked: str,
    reason: str | None = None,
) -> None:
    emit_structured(
        "daftar.agent.call",
        message=f"call_plan status={status}",
        action="plan",
        correlationId=correlation_id,
        batchId=batch_id,
        status=status,
        reason=reason,
        phoneMasked=phone_masked,
    )


def _parse_request(data: Any) -> PlanBatchRequest:
    if not isinstance(data, dict):
        raise HTTPException(status_code=400, detail="invalid_request_json")
    recipients = data.get("recipients")
    if isinstance(recipients, list) and (
        len(recipients) == 0 or len(recipients) > MAX_RECIPIENTS
    ):
        raise HTTPException(status_code=400, detail="recipients_cap_exceeded")
    try:
        return PlanBatchRequest.model_validate(data)
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=_validation_detail(exc)) from exc


def _plan_row(
    recipient: CallRecipient,
    *,
    settings: CallSettings,
    dry_run: bool,
    store: ConfirmHandleStore,
    batch_id: UUID,
) -> PlanBatchRowResult:
    phone = recipient.phoneE164.strip()
    masked = mask_e164(phone)
    contact_key = str(recipient.contactId)
    batch_key = str(batch_id)

    def reject(reason: RejectReason) -> PlanBatchRowResult:
        store.delete(batch_key, contact_key)
        return PlanBatchRowResult(
            contactId=recipient.contactId,
            phoneMasked=masked,
            readyToRun=False,
            status="rejected",
            reason=reason,
        )

    if not is_valid_e164(phone):
        return reject("invalidPhone")

    region_reason = region_gate(
        phone=phone,
        region=recipient.region,
        allowlist_region=settings.allowlist_region,
    )
    if region_reason == "unsupportedRegion":
        return reject("unsupportedRegion")

    if recipient.doNotCall:
        return reject("dnc")

    if phone not in settings.allowlist:
        return reject("notAllowlisted")

    if dry_run:
        return PlanBatchRowResult(
            contactId=recipient.contactId,
            phoneMasked=masked,
            readyToRun=False,
            status="dryRun",
            task=recipient.task,
        )

    if not settings.allow_dial:
        return reject("killSwitch")

    token = new_confirm_handle()
    store.put(batch_key, contact_key, token)
    return PlanBatchRowResult(
        contactId=recipient.contactId,
        phoneMasked=masked,
        readyToRun=True,
        status="planned",
        task=recipient.task,
        confirmHandle=token,
    )


@router.post("/v1/calls/plan-batch")
async def plan_batch(
    request: Request,
    settings: Annotated[CallSettings, Depends(get_call_settings)],
    store: Annotated[ConfirmHandleStore, Depends(get_handle_store)],
) -> JSONResponse:
    try:
        data = await request.json()
    except Exception as exc:
        raise HTTPException(status_code=400, detail="invalid_request_json") from exc

    body = _parse_request(data)
    correlation_id = str(body.correlationId)
    batch_id = str(body.batchId)
    results: list[PlanBatchRowResult] = []
    for recipient in body.recipients:
        row = _plan_row(
            recipient,
            settings=settings,
            dry_run=body.dryRun,
            store=store,
            batch_id=body.batchId,
        )
        results.append(row)
        _emit_plan(
            correlation_id=correlation_id,
            batch_id=batch_id,
            status=row.status,
            phone_masked=row.phoneMasked,
            reason=row.reason,
        )

    payload = PlanBatchResponse(batchId=body.batchId, results=results)
    return JSONResponse(
        content=payload.model_dump(mode="json", exclude_none=True),
    )
