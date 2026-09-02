"""Mask E.164 for logs and API responses. Never print the full number."""

from __future__ import annotations


def mask_e164(phone: str) -> str:
    digits = phone[-4:] if len(phone) >= 4 else "????"
    return f"+…{digits}"
