"""Appendix J.7 request/response models. Extra fields (``body``, ``amountMinor``) forbidden."""

from __future__ import annotations

from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

MAX_RECIPIENTS = 20
MAX_PDF_BYTES = 5 * 1024 * 1024

Locale = Literal["ar", "en"]
RowStatus = Literal["sent", "failed", "skippedDuplicate"]


class EmailRecipient(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contactId: UUID
    to: str
    subject: str = Field(min_length=1)
    customer_name: str = Field(min_length=1)
    store_name: str = Field(min_length=1)
    amount_line: str = Field(min_length=1)
    cta_line: str = Field(min_length=1)
    note: str = ""
    filename: str | None = None


class EmailSendBatchManifest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    batchId: UUID
    correlationId: UUID
    locale: Locale
    recipients: list[EmailRecipient] = Field(max_length=MAX_RECIPIENTS)


class EmailSendRowResult(BaseModel):
    model_config = ConfigDict(extra="forbid")

    contactId: UUID
    toMasked: str
    status: RowStatus
    smtpMessageId: str | None = None
    smtpCode: int | None = None
    smtpMessage: str | None = None


class EmailSendBatchResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    batchId: UUID
    results: list[EmailSendRowResult]
    needsHuman: bool
