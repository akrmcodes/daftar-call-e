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
]


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
