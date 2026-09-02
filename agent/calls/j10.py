"""J.10 region gate. Supported ISO codes follow CALL-E GitHub (Sep 2026). YE is never eligible.

NANP +1 is US and CA (and others). Demo region comes from CALLE_ALLOWLIST_REGION,
never inferred from a leading +1.
"""

from __future__ import annotations

import re

# GitHub call-e-integrations README — Supported Regions (snapshot Sep 2026)
# plus J.10 Arabic demo EG. YE is intentionally absent.
SUPPORTED_REGIONS: frozenset[str] = frozenset(
    {
        "AE",
        "AU",
        "BD",
        "BR",
        "BW",
        "CA",
        "CM",
        "DE",
        "EG",
        "ES",
        "FI",
        "FR",
        "GB",
        "GH",
        "HN",
        "ID",
        "IE",
        "IL",
        "IN",
        "JP",
        "KE",
        "LK",
        "MX",
        "MY",
        "MZ",
        "NA",
        "NG",
        "NL",
        "OM",
        "PH",
        "PK",
        "PL",
        "SA",
        "SG",
        "TH",
        "TN",
        "TR",
        "TW",
        "UA",
        "US",
        "VN",
        "ZA",
    }
)

# Non-NANP calling-code prefix → ISO. Longest prefix wins.
_CALLING_PREFIXES: tuple[tuple[str, str], ...] = tuple(
    sorted(
        (
            ("20", "EG"),
            ("27", "ZA"),
            ("31", "NL"),
            ("33", "FR"),
            ("34", "ES"),
            ("44", "GB"),
            ("48", "PL"),
            ("49", "DE"),
            ("52", "MX"),
            ("55", "BR"),
            ("60", "MY"),
            ("61", "AU"),
            ("62", "ID"),
            ("63", "PH"),
            ("65", "SG"),
            ("66", "TH"),
            ("81", "JP"),
            ("84", "VN"),
            ("90", "TR"),
            ("91", "IN"),
            ("92", "PK"),
            ("94", "LK"),
            ("216", "TN"),
            ("233", "GH"),
            ("234", "NG"),
            ("237", "CM"),
            ("254", "KE"),
            ("258", "MZ"),
            ("264", "NA"),
            ("267", "BW"),
            ("353", "IE"),
            ("358", "FI"),
            ("380", "UA"),
            ("504", "HN"),
            ("880", "BD"),
            ("886", "TW"),
            ("966", "SA"),
            ("967", "YE"),
            ("968", "OM"),
            ("971", "AE"),
            ("972", "IL"),
        ),
        key=lambda item: len(item[0]),
        reverse=True,
    )
)

_E164_RE = re.compile(r"^\+[1-9]\d{7,14}$")

NANP = "NANP"


def is_valid_e164(phone: str) -> bool:
    return bool(_E164_RE.match(phone))


def calling_region(phone: str) -> str | None:
    """ISO or NANP or YE from the digits after +. None if unknown prefix."""
    if not phone.startswith("+"):
        return None
    digits = phone[1:]
    if digits.startswith("1"):
        return NANP
    for prefix, iso in _CALLING_PREFIXES:
        if digits.startswith(prefix):
            return iso
    return None


def region_gate(
    *,
    phone: str,
    region: str,
    allowlist_region: str,
) -> str | None:
    """Return a J.9 reason or None if the region/calling-code pair is eligible.

    Does not check the allowlist.
    """
    iso = region.strip().upper()
    if iso == "YE" or calling_region(phone) == "YE":
        return "unsupportedRegion"
    mapped = calling_region(phone)
    if mapped is None:
        return "unsupportedRegion"
    if mapped == NANP:
        want = allowlist_region.strip().upper()
        if iso != want or iso not in SUPPORTED_REGIONS:
            return "unsupportedRegion"
        return None
    if iso != mapped or iso not in SUPPORTED_REGIONS:
        return "unsupportedRegion"
    return None
