"""Recipient masking — same helper as §4.6 smoke (never log full ``to``)."""

from __future__ import annotations


def mask_email(address: str) -> str:
    """Mask a mailbox: local-part last-4, or ``m***@domain`` when shorter."""
    local, _, domain = address.partition("@")
    if not domain:
        return "***"
    if len(local) >= 4:
        return f"***{local[-4:]}@{domain}"
    if not local:
        return f"***@{domain}"
    return f"{local[:1]}***@{domain}"
