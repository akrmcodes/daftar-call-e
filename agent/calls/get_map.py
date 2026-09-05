"""Map CALL-E snake_case call dict to J.9 GET camelCase. Never pass through raw blob."""

from __future__ import annotations

import re
from typing import Any

from calls.masking import mask_e164
from calls.schemas import CallGetResponse, CallStructuredResult, OUTCOME_VALUES

TERMINAL_STATUSES = frozenset({"completed", "failed", "canceled"})
_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _coerce_int_field(value: object) -> tuple[int | None, bool]:
    """Return (value, invalid). invalid=True means omit and may trigger needsHuman."""
    if value is None:
        return None, False
    if isinstance(value, bool):
        return None, True
    if isinstance(value, int):
        return value, False
    if isinstance(value, float) and value.is_integer():
        return int(value), False
    return None, True


def _phone_from_call(call: dict[str, Any]) -> str:
    recipients = call.get("recipients")
    if isinstance(recipients, list):
        for recipient in recipients:
            if not isinstance(recipient, dict):
                continue
            phones = recipient.get("phones")
            if not isinstance(phones, list):
                continue
            for phone in phones:
                if isinstance(phone, str) and phone.strip():
                    return mask_e164(phone.strip())
    return "+…????"


def _merge_task_fields(structured: dict[str, Any], out: dict[str, Any]) -> bool:
    """Return True if any task field was invalid."""
    invalid = False
    completed = structured.get("completed_count")
    if completed is None:
        return invalid
    coerced, bad = _coerce_int_field(completed)
    if bad:
        invalid = True
    elif coerced is not None:
        out["completed_count"] = coerced
    return invalid


def _merge_recipient_fields(structured: dict[str, Any], out: dict[str, Any]) -> bool:
    invalid = False
    outcome = structured.get("outcome")
    if isinstance(outcome, str) and outcome in OUTCOME_VALUES:
        out["outcome"] = outcome
    elif outcome is not None:
        invalid = True

    amount_raw = structured.get("promised_amount_minor")
    if amount_raw is not None:
        coerced, bad = _coerce_int_field(amount_raw)
        if bad:
            invalid = True
        else:
            out["promised_amount_minor"] = coerced

    currency = structured.get("promised_currency")
    if currency is not None:
        if isinstance(currency, str):
            out["promised_currency"] = currency
        else:
            invalid = True

    promised_date = structured.get("promised_date")
    if promised_date is not None:
        if isinstance(promised_date, str) and _DATE_RE.fullmatch(promised_date):
            out["promised_date"] = promised_date
        else:
            invalid = True

    language = structured.get("language")
    if language is not None:
        if language in ("ar", "en"):
            out["language"] = language
        else:
            invalid = True

    acknowledged = structured.get("acknowledged_hold")
    if acknowledged is not None:
        if isinstance(acknowledged, bool):
            out["acknowledged_hold"] = acknowledged
        else:
            invalid = True

    quote = structured.get("evidence_quote")
    if quote is not None:
        if isinstance(quote, str):
            out["evidence_quote"] = quote
        else:
            invalid = True

    return invalid


def _build_structured_result(call: dict[str, Any]) -> tuple[CallStructuredResult | None, bool]:
    merged: dict[str, Any] = {}
    invalid = False

    task_structured = call.get("structured_result")
    if isinstance(task_structured, dict):
        invalid = _merge_task_fields(task_structured, merged) or invalid

    recipients = call.get("recipients")
    if isinstance(recipients, list):
        for recipient in recipients:
            if not isinstance(recipient, dict):
                continue
            rec_structured = recipient.get("structured_result")
            if isinstance(rec_structured, dict):
                invalid = _merge_recipient_fields(rec_structured, merged) or invalid
            break

    if not merged:
        return None, invalid
    return CallStructuredResult.model_validate(merged), invalid


def map_call_get_response(
    run_id: str,
    call: dict[str, Any],
    *,
    phone_masked_hint: str | None = None,
) -> CallGetResponse:
    status_raw = call.get("status")
    status = status_raw if isinstance(status_raw, str) and status_raw else "unknown"
    terminal = status in TERMINAL_STATUSES

    task_completed_raw = call.get("task_completed")
    task_completed: bool | None = None
    if isinstance(task_completed_raw, bool):
        task_completed = task_completed_raw

    structured, schema_invalid = _build_structured_result(call)
    phone_masked = phone_masked_hint or _phone_from_call(call)

    needs_human = False
    if schema_invalid:
        needs_human = True
    elif status == "completed":
        needs_human = False
    elif terminal:
        if structured is None or structured.outcome is None:
            needs_human = True
    elif task_completed is True and (structured is None or schema_invalid):
        needs_human = True

    return CallGetResponse(
        runId=run_id,
        status=status,
        terminal=terminal,
        taskCompleted=task_completed,
        structuredResult=structured,
        phoneMasked=phone_masked,
        needsHuman=needs_human,
    )
