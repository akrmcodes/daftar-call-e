"""POST /v1/calls/plan-batch and run-batch. Auth is Cloud Run IAM + Appendix J."""

from __future__ import annotations

import asyncio
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from closing_agent.observability import emit_structured
from calls.client import CallCreator, StdlibCallCreator
from calls.handles import (
    ConfirmHandleStore,
    InMemoryConfirmHandleStore,
    PlanSnapshot,
    new_confirm_handle,
    token_matches,
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
    RunBatchRequest,
    RunBatchResponse,
    RunBatchRowResult,
    RunRecipient,
    Trigger,
)
from calls.settings import CallSettings

router = APIRouter(tags=["calls"])

_default_store = InMemoryConfirmHandleStore()
_default_creator = StdlibCallCreator()


def get_call_settings() -> CallSettings:
    return CallSettings.from_env()


def get_handle_store() -> ConfirmHandleStore:
    return _default_store


def get_call_creator() -> CallCreator:
    return _default_creator


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


def _emit_call(
    *,
    action: str,
    correlation_id: str,
    batch_id: str,
    status: str,
    phone_masked: str,
    reason: str | None = None,
    run_id: str | None = None,
) -> None:
    emit_structured(
        "daftar.agent.call",
        message=f"call_{action} status={status}",
        action=action,
        correlationId=correlation_id,
        batchId=batch_id,
        status=status,
        reason=reason,
        phoneMasked=phone_masked,
        runId=run_id,
    )


def _parse_plan(data: Any) -> PlanBatchRequest:
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


def _parse_run(data: Any) -> RunBatchRequest:
    if not isinstance(data, dict):
        raise HTTPException(status_code=400, detail="invalid_request_json")
    recipients = data.get("recipients")
    if isinstance(recipients, list) and (
        len(recipients) == 0 or len(recipients) > MAX_RECIPIENTS
    ):
        raise HTTPException(status_code=400, detail="recipients_cap_exceeded")
    try:
        return RunBatchRequest.model_validate(data)
    except ValidationError as exc:
        raise HTTPException(status_code=400, detail=_validation_detail(exc)) from exc


def _snapshot_gate(
    snapshot: PlanSnapshot,
    settings: CallSettings,
) -> RejectReason | None:
    phone = snapshot.phone_e164.strip()
    if not is_valid_e164(phone):
        return "invalidPhone"
    if region_gate(
        phone=phone,
        region=snapshot.region,
        allowlist_region=settings.allowlist_region,
    ) == "unsupportedRegion":
        return "unsupportedRegion"
    if snapshot.do_not_call:
        return "dnc"
    if phone not in settings.allowlist:
        return "notAllowlisted"
    return None


def _plan_row(
    recipient: CallRecipient,
    *,
    settings: CallSettings,
    dry_run: bool,
    store: ConfirmHandleStore,
    batch_id: UUID,
    trigger: Trigger,
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
    store.put(
        batch_key,
        contact_key,
        PlanSnapshot(
            token=token,
            phone_e164=phone,
            region=recipient.region.strip(),
            locale=recipient.locale,
            task=recipient.task,
            do_not_call=recipient.doNotCall,
            trigger=trigger,
        ),
    )
    return PlanBatchRowResult(
        contactId=recipient.contactId,
        phoneMasked=masked,
        readyToRun=True,
        status="planned",
        task=recipient.task,
        confirmHandle=token,
    )


async def _run_row(
    recipient: RunRecipient,
    *,
    settings: CallSettings,
    store: ConfirmHandleStore,
    creator: CallCreator,
    batch_id: str,
    correlation_id: str,
) -> tuple[RunBatchRowResult, bool]:
    contact_key = str(recipient.contactId)
    existing = store.get_run_id(batch_id, contact_key)
    if existing:
        snap = store.get(batch_id, contact_key)
        masked = mask_e164(snap.phone_e164) if snap else "+…????"
        return (
            RunBatchRowResult(
                contactId=recipient.contactId,
                status="skippedDuplicate",
                runId=existing,
                phoneMasked=masked,
            ),
            False,
        )

    snapshot = store.get(batch_id, contact_key)
    if snapshot is None or not token_matches(snapshot.token, recipient.confirmHandle):
        return (
            RunBatchRowResult(
                contactId=recipient.contactId,
                status="rejected",
                reason="invalidHandle",
            ),
            False,
        )

    masked = mask_e164(snapshot.phone_e164)
    gate = _snapshot_gate(snapshot, settings)
    if gate is not None:
        return (
            RunBatchRowResult(
                contactId=recipient.contactId,
                status="rejected",
                reason=gate,
                phoneMasked=masked,
            ),
            False,
        )

    metadata = {
        "batchId": batch_id,
        "correlationId": correlation_id,
        "contactId": contact_key,
        "trigger": snapshot.trigger,
    }
    idempotency_key = f"{batch_id}:{contact_key}"
    try:
        run_id = await asyncio.to_thread(
            lambda: creator.create(
                api_key_file=settings.api_key_file,
                task=snapshot.task,
                phone=snapshot.phone_e164,
                region=snapshot.region,
                locale=snapshot.locale,
                metadata=metadata,
                idempotency_key=idempotency_key,
            )
        )
    except Exception:
        return (
            RunBatchRowResult(
                contactId=recipient.contactId,
                status="failed",
                phoneMasked=masked,
            ),
            True,
        )

    store.put_run_id(batch_id, contact_key, run_id)
    store.delete(batch_id, contact_key)
    return (
        RunBatchRowResult(
            contactId=recipient.contactId,
            status="queued",
            runId=run_id,
            phoneMasked=masked,
        ),
        False,
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

    body = _parse_plan(data)
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
            trigger=body.trigger,
        )
        results.append(row)
        _emit_call(
            action="plan",
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


@router.post("/v1/calls/run-batch")
async def run_batch(
    request: Request,
    settings: Annotated[CallSettings, Depends(get_call_settings)],
    store: Annotated[ConfirmHandleStore, Depends(get_handle_store)],
    creator: Annotated[CallCreator, Depends(get_call_creator)],
) -> JSONResponse:
    try:
        data = await request.json()
    except Exception as exc:
        raise HTTPException(status_code=400, detail="invalid_request_json") from exc

    body = _parse_run(data)
    if not settings.allow_dial:
        return JSONResponse(
            status_code=403,
            content={"detail": "killSwitch", "needsHuman": True},
        )

    correlation_id = str(body.correlationId)
    batch_id = str(body.batchId)
    results: list[RunBatchRowResult] = []
    needs_human = False
    for recipient in body.recipients:
        row, human = await _run_row(
            recipient,
            settings=settings,
            store=store,
            creator=creator,
            batch_id=batch_id,
            correlation_id=correlation_id,
        )
        needs_human = needs_human or human
        results.append(row)
        _emit_call(
            action="run",
            correlation_id=correlation_id,
            batch_id=batch_id,
            status=row.status,
            phone_masked=row.phoneMasked or "",
            reason=row.reason,
            run_id=row.runId,
        )

    payload = RunBatchResponse(
        batchId=body.batchId,
        results=results,
        needsHuman=needs_human,
    )
    return JSONResponse(
        content=payload.model_dump(mode="json", exclude_none=True),
    )
