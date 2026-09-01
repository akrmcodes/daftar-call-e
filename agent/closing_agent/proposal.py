"""Appendix J proposal helpers — envelope, money/UUID guards, daftarContext.

Tools return either an ``AgentProposal`` dict or an error dict
``{status: "error", error_message: ...}`` (no ``proposalId``) so the LLM can retry.
"""

from __future__ import annotations

import re
import uuid
from typing import Any, Mapping, Optional

# OpenAPI GoalClass enum
GOAL_CLASSES = frozenset(
    {
        "capture_debt",
        "capture_payment",
        "ask",
        "close_day",
        "statement",
        "create_contact",
        "create_ledger",
        "backup_only",
    }
)

LEDGER_TYPES = frozenset({"customers", "suppliers", "personal", "custom"})

PROPOSAL_TOOLS = frozenset(
    {
        "parse_goal",
        "propose_debt",
        "propose_payment",
        "propose_create_contact",
        "propose_create_ledger",
        "propose_closing_plan",
        "propose_whatsapp_drafts",
        "propose_statement",
    }
)

# Matches OpenAPI Uuid schema (UUID v1–v5)
_UUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-"
    r"[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"
)

# Flutter CurrencyPrecision.decimalPlacesForCode — keep in sync.
# Spoken-major grammar is a twin of
# lib/application/agent/correct_spoken_amount_minor.dart — keep in sync.
_ZERO_DECIMAL_CURRENCIES = frozenset({"YER"})
_SPOKEN_INT_RE = re.compile(r"(?<![\d.])(\d+)(?![\d.])")
_ARABIC_INDIC = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
_ALEF_VARIANTS = str.maketrans("أإآٱ", "اااا")
_TATWEEL_TASHKEEL_RE = re.compile(r"[\u0640\u064B-\u065F\u0670]")
_MIXED_DIGIT_SCALE_EN = re.compile(
    r"(\d+)\s*(hundreds?|thousands?|millions?|k)\b",
    re.IGNORECASE,
)
_MIXED_DIGIT_SCALE_AR = re.compile(
    r"(\d+)\s*(مائة|مئة|ميه|مية|مئه|الاف|الف|مليون)(?![\u0600-\u06FF])"
)
_CURRENCY_EN = re.compile(
    r"(\d+)\s*(?:riyals?|yer|sar|usd)\b|(?:riyals?|yer|sar|usd)\b\s*(\d+)",
    re.IGNORECASE,
)
_CURRENCY_AR = re.compile(r"(\d+)\s*ريال|ريال\s*(\d+)")
_GLUED_HUNDRED = re.compile(
    r"^(اثنين|اثنان|اثنتين|اتنين|ثلاثة|ثلاث|اربعة|اربع|خمسة|خمس|"
    r"ستة|ست|سبعة|سبع|ثمانية|ثماني|ثمان|تسعة|تسع)"
    r"(مائة|مئة|ميه|مية|مئه)$"
)
_SCALE_FOR = {
    "hundred": 100,
    "hundreds": 100,
    "مائة": 100,
    "مئة": 100,
    "ميه": 100,
    "مية": 100,
    "مئه": 100,
    "thousand": 1000,
    "thousands": 1000,
    "k": 1000,
    "الف": 1000,
    "الاف": 1000,
    "million": 1000000,
    "millions": 1000000,
    "مليون": 1000000,
}
_EN_ONES = {
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
    "thirteen": 13,
    "fourteen": 14,
    "fifteen": 15,
    "sixteen": 16,
    "seventeen": 17,
    "eighteen": 18,
    "nineteen": 19,
}
_EN_TENS = {
    "twenty": 20,
    "thirty": 30,
    "forty": 40,
    "fifty": 50,
    "sixty": 60,
    "seventy": 70,
    "eighty": 80,
    "ninety": 90,
}
_AR_ONES = {
    "واحد": 1,
    "واحدة": 1,
    "احد": 1,
    "اثنين": 2,
    "اثنان": 2,
    "اثنتين": 2,
    "اتنين": 2,
    "ثلاثة": 3,
    "ثلاث": 3,
    "اربعة": 4,
    "اربع": 4,
    "خمسة": 5,
    "خمس": 5,
    "ستة": 6,
    "ست": 6,
    "سبعة": 7,
    "سبع": 7,
    "ثمانية": 8,
    "ثماني": 8,
    "ثمان": 8,
    "تسعة": 9,
    "تسع": 9,
    "عشرة": 10,
    "عشر": 10,
}
_AR_TENS = {
    "عشرون": 20,
    "عشرين": 20,
    "ثلاثون": 30,
    "ثلاثين": 30,
    "اربعون": 40,
    "اربعين": 40,
    "خمسون": 50,
    "خمسين": 50,
    "ستون": 60,
    "ستين": 60,
    "سبعون": 70,
    "سبعين": 70,
    "ثمانون": 80,
    "ثمانين": 80,
    "تسعون": 90,
    "تسعين": 90,
}
_AR_HUNDRED = {
    "مئة": 100,
    "مائة": 100,
    "مائه": 100,
    "مئه": 100,
    "ميه": 100,
    "مية": 100,
    "مئتان": 200,
    "مائتان": 200,
    "مئتين": 200,
    "مائتين": 200,
    "ميتين": 200,
}
_AR_THOUSAND = {
    "الف": 1000,
    "الاف": 1000,
    "الفان": 2000,
    "الفين": 2000,
}
_AR_MILLION = {
    "مليون": 1000000,
    "ملايين": 1000000,
    "مليونين": 2000000,
    "مليونان": 2000000,
}
_EN_WORD_RE = re.compile(r"[a-z]+", re.IGNORECASE)
_AR_WORD_RE = re.compile(r"[\u0600-\u06FF]+")

# Tools that always require device confirm (Appendix J.3)
_CONFIRM_ALWAYS = frozenset(
    {
        "propose_debt",
        "propose_payment",
        "propose_create_contact",
        "propose_create_ledger",
        "propose_closing_plan",
        "propose_whatsapp_drafts",
        "propose_statement",
    }
)


def error(message: str) -> dict[str, Any]:
    """LLM-retryable failure — never includes proposalId."""
    return {"status": "error", "error_message": message}


def make_proposal(
    tool: str,
    payload: dict[str, Any],
    *,
    confirm_required: Optional[bool] = None,
) -> dict[str, Any]:
    """Build an Appendix J AgentProposal envelope."""
    if tool not in PROPOSAL_TOOLS:
        return error(f"Unknown tool name: {tool}")
    if confirm_required is None:
        confirm_required = tool in _CONFIRM_ALWAYS
    return {
        "proposalId": str(uuid.uuid4()),
        "tool": tool,
        "payload": payload,
        "confirmRequired": bool(confirm_required),
    }


def is_proposal(result: Mapping[str, Any]) -> bool:
    return "proposalId" in result and "tool" in result and "payload" in result


def require_nonempty_str(value: Any, field: str) -> str | dict[str, Any]:
    if not isinstance(value, str) or not value.strip():
        return error(f"{field} must be a non-empty string")
    return value.strip()


def require_amount_minor(value: Any) -> int | dict[str, Any]:
    """Strict integer money: reject bool, float, str, and non-positive values."""
    if isinstance(value, bool) or not isinstance(value, int):
        return error(
            "amount_minor must be a positive Python int (smallest currency unit). "
            "Never float, bool, or string."
        )
    if value <= 0:
        return error("amount_minor must be > 0")
    return value


def is_uuid(value: Any) -> bool:
    return isinstance(value, str) and bool(_UUID_RE.match(value.strip()))


def require_uuid(value: Any, field: str = "id") -> str | dict[str, Any]:
    if not is_uuid(value):
        return error(f"{field} must be a UUID string")
    return value.strip()


def optional_uuid(value: Any, field: str = "id") -> str | None | dict[str, Any]:
    if value is None or (isinstance(value, str) and not value.strip()):
        return None
    return require_uuid(value, field)


def get_daftar_context(tool_context: Any) -> dict[str, Any]:
    """Read Appendix J DeviceAgentRequest from session state (may be empty)."""
    if tool_context is None:
        return {}
    state = getattr(tool_context, "state", None)
    if state is None:
        return {}
    try:
        ctx = state.get("daftarContext")
    except Exception:
        ctx = None
    if isinstance(ctx, Mapping):
        return dict(ctx)
    return {}


def default_currency(ctx: Mapping[str, Any]) -> str:
    code = ctx.get("defaultCurrency")
    if isinstance(code, str) and code.strip():
        return code.strip().upper()
    return "YER"


def is_multi_currency(ctx: Mapping[str, Any]) -> bool:
    return bool(ctx.get("isMultiCurrencyEnabled"))


def ledgers(ctx: Mapping[str, Any]) -> list[dict[str, Any]]:
    raw = ctx.get("ledgers")
    if not isinstance(raw, list):
        return []
    return [x for x in raw if isinstance(x, Mapping)]


def voice_hints(ctx: Mapping[str, Any]) -> list[dict[str, Any]]:
    raw = ctx.get("voiceHints")
    if not isinstance(raw, list):
        return []
    return [x for x in raw if isinstance(x, Mapping)]


def display_name_for_contact_id(ctx: Mapping[str, Any], contact_id: str) -> str:
    """Spoken displayName for a UUID, or empty."""
    cid = contact_id.strip()
    if not is_uuid(cid):
        return ""
    for vh in voice_hints(ctx):
        hid = vh.get("contactId")
        name = vh.get("displayName")
        if not isinstance(hid, str) or not isinstance(name, str):
            continue
        if hid.strip() != cid:
            continue
        spoken = name.strip()
        if spoken and not is_uuid(spoken):
            return spoken
    return ""


def spoken_hint_and_id(
    ctx: Mapping[str, Any],
    *,
    contact_hint: str = "",
    contact_id: str = "",
) -> tuple[str, str]:
    """Return (spoken_hint, uuid). The hint is never a UUID."""
    cid = contact_id.strip() if isinstance(contact_id, str) else ""
    if cid and not is_uuid(cid):
        cid = ""
    hint = contact_hint.strip() if isinstance(contact_hint, str) else ""
    if hint and is_uuid(hint):
        if not cid:
            cid = hint
        hint = ""
    if cid and not hint:
        hint = display_name_for_contact_id(ctx, cid)
    return hint, cid


def merchant_local_day(ctx: Mapping[str, Any]) -> str | None:
    day = ctx.get("merchantLocalDay")
    if isinstance(day, str) and day.strip():
        return day.strip()
    return None


def resolve_currency(ctx: Mapping[str, Any], currency_code: str = "") -> str:
    """Empty → defaultCurrency; if multi-currency off, force defaultCurrency."""
    default = default_currency(ctx)
    if not is_multi_currency(ctx):
        return default
    if isinstance(currency_code, str) and currency_code.strip():
        return currency_code.strip().upper()
    return default


def _minor_unit_factor(currency_code: str) -> int:
    """Match Flutter CurrencyPrecision.minorUnitFactor."""
    if currency_code.upper() in _ZERO_DECIMAL_CURRENCIES:
        return 1
    return 100


def _normalize_spoken_text(goal: str) -> str:
    translated = goal.translate(_ARABIC_INDIC).translate(_ALEF_VARIANTS)
    stripped = _TATWEEL_TASHKEEL_RE.sub("", translated)
    return (
        stripped.replace(",", "")
        .replace("٬", "")
        .replace("،", "")
        .replace("_", "")
    )


def _is_year(value: int) -> bool:
    return 1900 <= value <= 2100


def _from_mixed_digit_scale(text: str) -> int | None:
    matches = list(_MIXED_DIGIT_SCALE_EN.finditer(text)) + list(
        _MIXED_DIGIT_SCALE_AR.finditer(text)
    )
    if not matches:
        return None
    match = max(matches, key=lambda m: m.start())
    n = int(match.group(1))
    if n <= 0:
        return None
    scale = _SCALE_FOR.get(match.group(2).lower())
    if scale is None:
        return None
    value = n * scale
    return value if value > 0 else None


def _from_currency_anchored_digit(text: str) -> int | None:
    matches = list(_CURRENCY_EN.finditer(text)) + list(_CURRENCY_AR.finditer(text))
    matches.sort(key=lambda m: m.start())
    for match in reversed(matches):
        raw = match.group(1) or match.group(2)
        if raw is None:
            continue
        value = int(raw)
        if value > 0:
            return value
    return None


def _last_whole_integer(text: str) -> int | None:
    values = [
        int(m.group(1))
        for m in _SPOKEN_INT_RE.finditer(text)
        if int(m.group(1)) > 0
    ]
    if not values:
        return None
    non_years = [v for v in values if not _is_year(v)]
    if non_years:
        return non_years[-1]
    return values[-1]


def _from_english_words(text: str) -> int | None:
    tokens = [m.group(0).lower() for m in _EN_WORD_RE.finditer(text)]
    total = 0
    current = 0
    found = False
    i = 0
    while i < len(tokens):
        token = tokens[i]
        if token == "and":
            i += 1
            continue
        if token in {"a", "an"}:
            nxt = tokens[i + 1] if i + 1 < len(tokens) else ""
            if nxt in {
                "hundred",
                "hundreds",
                "thousand",
                "thousands",
                "million",
                "millions",
            }:
                current += 1
                found = True
            i += 1
            continue
        if token in _EN_ONES:
            current += _EN_ONES[token]
            found = True
        elif token in _EN_TENS:
            current += _EN_TENS[token]
            found = True
        elif token in {"hundred", "hundreds"}:
            current = (1 if current == 0 else current) * 100
            found = True
        elif token in {"thousand", "thousands"}:
            total += (1 if current == 0 else current) * 1000
            current = 0
            found = True
        elif token in {"million", "millions"}:
            total += (1 if current == 0 else current) * 1000000
            current = 0
            found = True
        i += 1
    if not found:
        return None
    value = total + current
    return value if value > 0 else None


def _glued_arabic_hundred(token: str) -> int | None:
    match = _GLUED_HUNDRED.match(token)
    if match is None:
        return None
    prefix = match.group(1)
    ones = _AR_ONES.get(prefix)
    if ones is None:
        return None
    return ones * 100


def _unwrap_arabic_waw(token: str) -> str:
    """Strip a leading glued و when the remainder is a number word."""
    if _is_arabic_amount_token(token):
        return token
    if token.startswith("و") and len(token) > 1:
        rest = token[1:]
        if _is_arabic_amount_token(rest):
            return rest
    return token


def _is_arabic_amount_token(token: str) -> bool:
    return (
        token in _AR_ONES
        or token in _AR_TENS
        or token in _AR_HUNDRED
        or token in _AR_THOUSAND
        or token in _AR_MILLION
        or _glued_arabic_hundred(token) is not None
    )


def _from_arabic_words(text: str) -> int | None:
    tokens = [m.group(0) for m in _AR_WORD_RE.finditer(text)]
    total = 0
    current = 0
    found = False
    for raw in tokens:
        token = _unwrap_arabic_waw(raw)
        if token == "و":
            continue
        glued = _glued_arabic_hundred(token)
        if glued is not None:
            current += glued
            found = True
            continue
        if token in _AR_ONES:
            current += _AR_ONES[token]
            found = True
        elif token in _AR_TENS:
            current += _AR_TENS[token]
            found = True
        elif token in _AR_HUNDRED:
            hundred = _AR_HUNDRED[token]
            if hundred == 200:
                current = 200
            else:
                current = (1 if current == 0 else current) * 100
            found = True
        elif token in _AR_THOUSAND:
            thousand = _AR_THOUSAND[token]
            if thousand == 2000:
                total += 2000
            else:
                total += (1 if current == 0 else current) * 1000
            current = 0
            found = True
        elif token in _AR_MILLION:
            million = _AR_MILLION[token]
            if million == 2000000:
                total += 2000000
            else:
                total += (1 if current == 0 else current) * 1000000
            current = 0
            found = True
    if not found:
        return None
    value = total + current
    return value if value > 0 else None


def parse_spoken_major(goal_text: str) -> int | None:
    """Spoken whole major amount, or None.

    Order: mixed digit+scale, EN/AR words, currency-anchored digit, last
    integer (years skipped when another integer exists). Twin of Dart
    ``parseSpokenMajor``.
    """
    normalized = _normalize_spoken_text(goal_text)
    if not normalized.strip():
        return None
    return (
        _from_mixed_digit_scale(normalized)
        or _from_english_words(normalized)
        or _from_arabic_words(normalized)
        or _from_currency_anchored_digit(normalized)
        or _last_whole_integer(normalized)
    )


def _voice_hint_display_names(ctx: Mapping[str, Any]) -> list[str]:
    names: list[str] = []
    for hint in voice_hints(ctx):
        name = hint.get("displayName")
        if isinstance(name, str) and name.strip():
            names.append(name.strip())
    return names


def _fold_search(value: str) -> str:
    return _normalize_spoken_text(value).casefold()


def _find_hint_index(
    haystack: str,
    needle: str,
    siblings: list[str],
) -> int:
    """First ``needle`` not shadowed by a longer sibling at the same index."""
    if not needle:
        return -1
    start = 0
    while True:
        pos = haystack.find(needle, start)
        if pos < 0:
            return -1
        shadowed = False
        for sib in siblings:
            if (
                len(sib) > len(needle)
                and sib.startswith(needle)
                and haystack.startswith(sib, pos)
            ):
                shadowed = True
                break
        if not shadowed:
            return pos
        start = pos + 1


def goal_slice_for_hint(
    goal_text: str,
    contact_hint: str,
    sibling_hints: list[str],
) -> str | None:
    """Goal substring from this contact hint until the next sibling name.

    Returns None when the hint is missing so callers fall back to a global
    parse. Twin of Dart ``_goalSliceForHint``.
    """
    hint_raw = contact_hint.strip() if isinstance(contact_hint, str) else ""
    if not hint_raw:
        return None
    goal_folded = _fold_search(goal_text)
    hint_folded = _fold_search(hint_raw)
    if not hint_folded:
        return None
    sibling_folded: list[str] = []
    for sib in sibling_hints:
        if not isinstance(sib, str) or not sib.strip():
            continue
        folded = _fold_search(sib)
        if folded and folded != hint_folded:
            sibling_folded.append(folded)
    start = _find_hint_index(goal_folded, hint_folded, sibling_folded)
    if start < 0:
        return None
    end = len(goal_folded)
    after = start + len(hint_folded)
    suffix = goal_folded[after:]
    for sib in sibling_folded:
        pos = _find_hint_index(suffix, sib, sibling_folded)
        if pos >= 0:
            abs_pos = after + pos
            if abs_pos < end:
                end = abs_pos
    return goal_folded[start:end]


def correct_zero_decimal_scale(
    ctx: Mapping[str, Any],
    currency_code: str,
    amount_minor: int,
    *,
    contact_hint: str = "",
) -> int:
    """Snap Gemini amountMinor to the spoken major in ``goalText``.

    When ``contact_hint`` is found, parse only the slice until the next
    ``voiceHints.displayName``. If the hint is missing, keep the global snap
    only when the amount still matches ``expected`` / ×10 / ×100.

    Parses spoken major ``S`` (digits or EN/AR words). Expected minor units
    are ``S * 10^exponent``. If the model amount is ``expected``,
    ``expected * 10``, or ``expected * 100``, return ``expected``.
    If it equals ``S`` and the currency has more than 0 decimal places
    (Gemini sent major units as minor), scale up to ``expected``.
    Digit strings such as ``"10000"`` are left alone when they already match.
    """
    goal = ctx.get("goalText")
    if not isinstance(goal, str) or not goal.strip():
        return amount_minor
    slice_text = goal_slice_for_hint(
        goal,
        contact_hint,
        _voice_hint_display_names(ctx),
    )
    spoken = parse_spoken_major(slice_text if slice_text is not None else goal)
    if spoken is None or spoken <= 0:
        return amount_minor
    factor = _minor_unit_factor(currency_code)
    expected = spoken * factor
    if amount_minor in (expected, expected * 10, expected * 100):
        return expected
    if factor > 1 and amount_minor == spoken:
        return expected
    return amount_minor


def fold_arabic_name(value: str) -> str:
    """Space-stripped, alef-folded name for unique voiceHints matching."""
    folded = value.strip().translate(_ALEF_VARIANTS).casefold()
    return re.sub(r"\s+", "", folded)


def resolve_contact_id(
    ctx: Mapping[str, Any],
    *,
    contact_id: str = "",
    contact_hint: str = "",
) -> str | None:
    """Return UUID from explicit id or unique voiceHints displayName."""
    if isinstance(contact_id, str) and contact_id.strip():
        checked = require_uuid(contact_id.strip(), "contactId")
        if isinstance(checked, dict):
            return None
        return checked
    hint = (contact_hint or "").strip()
    if not hint:
        return None
    hint_l = hint.casefold()
    hint_fold = fold_arabic_name(hint)
    exact: list[str] = []
    folded: list[str] = []
    for vh in voice_hints(ctx):
        name = vh.get("displayName")
        cid = vh.get("contactId")
        if not isinstance(name, str) or not isinstance(cid, str):
            continue
        cid = cid.strip()
        if not _UUID_RE.match(cid):
            continue
        if name.strip().casefold() == hint_l:
            exact.append(cid)
        elif hint_fold and fold_arabic_name(name) == hint_fold:
            folded.append(cid)
    if len(exact) == 1:
        return exact[0]
    if not exact and len(folded) == 1:
        return folded[0]
    return None


def resolve_contact_id_or_error(
    ctx: Mapping[str, Any],
    *,
    contact_id: str = "",
    contact_hint: str = "",
) -> str | dict[str, Any]:
    """Like resolve_contact_id but returns an error dict when unresolved."""
    if isinstance(contact_id, str) and contact_id.strip():
        return require_uuid(contact_id.strip(), "contactId")
    resolved = resolve_contact_id(ctx, contact_hint=contact_hint)
    if resolved:
        return resolved
    if contact_hint.strip():
        return error(
            f"contactId could not be resolved from voiceHints for hint "
            f"{contact_hint!r}; pass a UUID contact_id"
        )
    return error("contactId is required (UUID)")
