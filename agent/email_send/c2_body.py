"""Appendix C.2 body assembly — named params + locale. No LLM ``body``."""

from __future__ import annotations

from typing import Literal

Locale = Literal["ar", "en"]

# Exact templates from docs/roadmap_v2.md Appendix C.2 (do not reformat money).
C2_BODY_EN = (
    "Hello {{customer_name}}, this is {{store_name}}. "
    "Your outstanding balance is {{amount_line}}. "
    "{{cta_line}} {{note}} Thank you."
)

C2_BODY_AR = (
    "مرحباً {{customer_name}}، معك {{store_name}}. "
    "رصيدك المستحق {{amount_line}}. "
    "{{cta_line}} {{note}}شكراً لك."
)


def assemble_c2_body(
    *,
    locale: Locale,
    customer_name: str,
    store_name: str,
    amount_line: str,
    cta_line: str,
    note: str,
) -> str:
    """Fill C.2 placeholders. Server never touches ``amountMinor``."""
    template = C2_BODY_AR if locale == "ar" else C2_BODY_EN
    return (
        template.replace("{{customer_name}}", customer_name)
        .replace("{{store_name}}", store_name)
        .replace("{{amount_line}}", amount_line)
        .replace("{{cta_line}}", cta_line)
        .replace("{{note}}", note)
    )
