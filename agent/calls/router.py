"""POST /v1/calls/plan-batch and run-batch. Auth is Cloud Run IAM + Appendix J."""

from __future__ import annotations

import asyncio
import logging
from typing import Annotated, Any
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from closing_agent.observability import emit_structured
from calls.client import (
    CallCreator,
    CallNotFoundError,
    StdlibCallCreator,
    UpstreamAuthError,
    UpstreamUnavailableError,
)
from calls.get_map import map_call_get_response
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
from calls.spoken_locale import canonicalize_locale

router = APIRouter(tags=["calls"])
_log = logging.getLogger("daftar.calls")

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
    correlation_id: str = "",
    batch_id: str = "",
    status: str,
    phone_masked: str,
    reason: str | None = None,
    run_id: str | None = None,
    terminal: bool | None = None,
    outcome: str | None = None,
) -> None:
    fields: dict[str, object] = {
        "action": action,
        "status": status,
        "phoneMasked": phone_masked,
    }
    if correlation_id:
        fields["correlationId"] = correlation_id
    if batch_id:
        fields["batchId"] = batch_id
    if reason is not None:
        fields["reason"] = reason
    if run_id is not None:
        fields["runId"] = run_id
    if terminal is not None:
        fields["terminal"] = terminal
    if outcome is not None:
        fields["outcome"] = outcome
    emit_structured(
        "daftar.agent.call",
        message=f"call_{action} status={status}",
        **fields,
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
    attempt: int = 0,
) -> tuple[RunBatchRowResult, bool]:
    contact_key = str(recipient.contactId)
    if attempt == 1:
        existing_retry = store.get_retry_run_id(batch_id, contact_key)
        if existing_retry:
            snap = store.get(batch_id, contact_key)
            masked = mask_e164(snap.phone_e164) if snap else "+…????"
            return (
                RunBatchRowResult(
                    contactId=recipient.contactId,
                    status="skippedDuplicate",
                    runId=existing_retry,
                    phoneMasked=masked,
                ),
                False,
            )
        if store.get_run_id(batch_id, contact_key) is None:
            return (
                RunBatchRowResult(
                    contactId=recipient.contactId,
                    status="rejected",
                    reason="invalidHandle",
                ),
                False,
            )
    else:
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
    if attempt == 1:
        idempotency_key = f"{batch_id}:{contact_key}:retry1"
    else:
        idempotency_key = f"{batch_id}:{contact_key}"
    try:
        run_id = await asyncio.to_thread(
            lambda: creator.create(
                api_key_file=settings.api_key_file,
                task=snapshot.task,
                phone=snapshot.phone_e164,
                region=snapshot.region,
                locale=canonicalize_locale(
                    region=snapshot.region,
                    locale=snapshot.locale,
                ),
                metadata=metadata,
                idempotency_key=idempotency_key,
            )
        )
    except Exception as exc:
        _log.warning(
            "call_create_failed type=%s code=%s",
            type(exc).__name__,
            getattr(exc, "code", ""),
        )
        return (
            RunBatchRowResult(
                contactId=recipient.contactId,
                status="failed",
                phoneMasked=masked,
            ),
            True,
        )

    if attempt == 1:
        store.put_retry_run_id(batch_id, contact_key, run_id)
    else:
        store.put_run_id(batch_id, contact_key, run_id)
    store.put_run_mask(run_id, masked)
    store.put_run_context(run_id, batch_id, correlation_id)
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
    if body.attempt >= 2:
        raise HTTPException(status_code=400, detail="invalid_request:attempt")
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
            attempt=body.attempt,
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


@router.get("/v1/calls/{runId}")
async def get_call(
    runId: str,
    settings: Annotated[CallSettings, Depends(get_call_settings)],
    store: Annotated[ConfirmHandleStore, Depends(get_handle_store)],
    creator: Annotated[CallCreator, Depends(get_call_creator)],
) -> JSONResponse:
    run_id = runId.strip()
    if not run_id:
        raise HTTPException(status_code=400, detail="invalid_run_id")

    try:
        call = await asyncio.to_thread(
            lambda: creator.get(
                api_key_file=settings.api_key_file,
                run_id=run_id,
            )
        )
    except CallNotFoundError as exc:
        raise HTTPException(status_code=404, detail="not_found") from exc
    except UpstreamAuthError as exc:
        return JSONResponse(
            status_code=502,
            content={"detail": "upstream_auth", "needsHuman": True},
        )
    except UpstreamUnavailableError as exc:
        return JSONResponse(
            status_code=502,
            content={"detail": "upstream_unavailable", "needsHuman": True},
        )
    except Exception:
        return JSONResponse(
            status_code=502,
            content={"detail": "upstream_unavailable", "needsHuman": True},
        )

    payload = map_call_get_response(
        run_id,
        call,
        phone_masked_hint=store.get_run_mask(run_id),
    )
    outcome = (
        payload.structuredResult.outcome
        if payload.structuredResult is not None
        else None
    )
    should_log_terminal = payload.terminal or (
        payload.needsHuman
        and payload.status in {"failed", "canceled"}
    )
    if should_log_terminal:
        ctx = store.get_run_context(run_id)
        _emit_call(
            action="terminal",
            correlation_id=ctx.correlation_id if ctx is not None else "",
            batch_id=ctx.batch_id if ctx is not None else "",
            status=payload.status,
            phone_masked=payload.phoneMasked,
            run_id=payload.runId,
            terminal=payload.terminal,
            outcome=outcome,
        )
    return JSONResponse(
        content=payload.model_dump(mode="json", exclude_none=True),
    )
