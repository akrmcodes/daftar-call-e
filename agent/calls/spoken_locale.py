"""CALL-E spoken locale vs merchant UI locale.

UI `ar`/`en` is email and chrome. Recipient locale on create must be a
region-legal BCP-47 tag. US is English-only (`en-US`).

Keep in lockstep with the Flutter domain mapper of the same module name.
"""

from __future__ import annotations

ENGLISH_BCP47 = "en-US"
ARABIC_CAPABLE_REGIONS: frozenset[str] = frozenset({"AE", "SA", "EG", "OM"})


def _wants_arabic(locale: str) -> bool:
    return not locale.strip().lower().startswith("en")


def canonicalize_locale(*, region: str, locale: str) -> str:
    """Map stored plan locale + J.10 region to a CALL-E create tag."""
    iso = region.strip().upper()
    if _wants_arabic(locale) and iso in ARABIC_CAPABLE_REGIONS:
        return f"ar-{iso}"
    return ENGLISH_BCP47
