"""Kill switch + allowlist + NANP region. Not Envied. Never log E.164."""

from __future__ import annotations

import os
from dataclasses import dataclass


def parse_allow_dial(raw: str | None) -> bool:
    """PSTN / run-batch only if the value is the exact lowercase string true."""
    return (raw or "") == "true"


def parse_allowlist(raw: str | None) -> frozenset[str]:
    entries: list[str] = []
    for part in (raw or "").split(","):
        item = part.strip()
        if item:
            entries.append(item)
    return frozenset(entries)


@dataclass(frozen=True)
class CallSettings:
    allow_dial: bool
    allowlist: frozenset[str]
    allowlist_region: str
    api_key_file: str = ""

    @classmethod
    def from_env(cls) -> CallSettings:
        region = os.environ.get("CALLE_ALLOWLIST_REGION", "").strip() or "US"
        return cls(
            allow_dial=parse_allow_dial(os.environ.get("CALLE_ALLOW_DIAL")),
            allowlist=parse_allowlist(os.environ.get("CALLE_ALLOWLIST")),
            allowlist_region=region,
            api_key_file=os.environ.get("CALLE_API_KEY_FILE", "").strip(),
        )
