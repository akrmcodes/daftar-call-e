"""Appendix J.9 plan-batch models. Extra fields forbidden."""

from __future__ import annotations

from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

MAX_RECIPIENTS = 5

Trigger = Literal["closeDay", "creditLimit"]
BatchLocale = Literal["ar", "en"]
RowStatus = Literal["planned", "dryRun", "rejected", "failed"]
RejectReason = Literal[
    "notAllowlisted",
    "unsupportedRegion",
    "killSwitch",
    "dnc",
    "invalidPhone",
    "invalidHandle",
]
RunStatus = Literal["queued", "rejected", "failed", "skippedDuplicate"]

TASK_RESULT_SCHEMA: dict[str, object] = {
    "type": "object",
    "required": ["completed_count"],
    "properties": {
        "completed_count": {"type": "integer"},
    },
}

RECIPIENT_RESULT_SCHEMA: dict[str, object] = {
    "type": "object",
    "required": ["outcome"],
    "properties": {
        "outcome": {
            "type": "string",
            "enum": [
                "promised",
                "refused",
                "voicemail",
                "no_answer",
                "wrong_number",
                "callback_requested",
            ],
        },
        "promised_amount_minor": {"type": ["integer", "null"]},
        "promised_currency": {"type": ["string", "null"]},
        "promised_date": {"type": ["string", "null"]},
        "language": {"type": "string", "enum": ["ar", "en"]},
        "acknowledged_hold": {"type": ["boolean", "null"]},
        "evidence_quote": {"type": ["string", "null"]},
    },
}


class CallRecipient(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contactId: UUID
    phoneE164: str = Field(min_length=2)
    region: str = Field(min_length=2, max_length=2)
    locale: str = Field(min_length=1)
    task: str = Field(min_length=1)
    customer_name: str = Field(min_length=1)
    store_name: str = Field(min_length=1)
    amount_line: str = Field(min_length=1)
    doNotCall: bool = False


class PlanBatchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    batchId: UUID
    correlationId: UUID
    trigger: Trigger
    dryRun: bool
    locale: BatchLocale
    recipients: list[CallRecipient] = Field(min_length=1, max_length=MAX_RECIPIENTS)


class PlanBatchRowResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contactId: UUID
    phoneMasked: str
    readyToRun: bool
    status: RowStatus
    reason: RejectReason | None = None
    task: str | None = None
    confirmHandle: str | None = None


class PlanBatchResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    batchId: UUID
    results: list[PlanBatchRowResult]


class RunRecipient(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contactId: UUID
    confirmHandle: str = Field(min_length=1)


class RunBatchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    batchId: UUID
    correlationId: UUID
    recipients: list[RunRecipient] = Field(min_length=1, max_length=MAX_RECIPIENTS)


class RunBatchRowResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contactId: UUID
    status: RunStatus
    runId: str | None = None
    reason: RejectReason | None = None
    phoneMasked: str | None = None


class RunBatchResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    batchId: UUID
    results: list[RunBatchRowResult]
    needsHuman: bool
