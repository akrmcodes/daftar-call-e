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
Outcome = Literal[
    "promised",
    "refused",
    "voicemail",
    "no_answer",
    "wrong_number",
    "callback_requested",
]
OUTCOME_VALUES = frozenset(
    {
        "promised",
        "refused",
        "voicemail",
        "no_answer",
        "wrong_number",
        "callback_requested",
    }
)

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
        "promised_amount_minor": {"type": "integer"},
        "promised_currency": {"type": "string"},
        "promised_date": {"type": "string"},
        "language": {"type": "string", "enum": ["ar", "en"]},
        "acknowledged_hold": {"type": "boolean"},
        "evidence_quote": {"type": "string"},
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
    attempt: Literal[0, 1] = 0


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


class CallStructuredResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    completed_count: int | None = None
    outcome: Outcome | None = None
    promised_amount_minor: int | None = None
    promised_currency: str | None = None
    promised_date: str | None = None
    language: Literal["ar", "en"] | None = None
    acknowledged_hold: bool | None = None
    evidence_quote: str | None = None


class CallGetResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    runId: str
    status: str
    terminal: bool
    taskCompleted: bool | None = None
    structuredResult: CallStructuredResult | None = None
    phoneMasked: str
    needsHuman: bool
