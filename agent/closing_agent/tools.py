"""ADK FunctionTools — Appendix J proposal surface (Stage 1.2).

Each success return is an AgentProposal envelope. Failures return
``{status: "error", error_message}`` without proposalId.
``tool_context`` is ADK-injected and omitted from the LLM schema.
"""

from __future__ import annotations

from typing import Any, Optional

from closing_agent import proposal as P


def parse_goal(
    goal_text: str,
    goal_class: str,
    tool_context: Any = None,
) -> dict[str, Any]:
    """Classify the merchant goal into a contest goalClass.

    Args:
        goal_text: Raw user utterance / typed goal.
        goal_class: One of capture_debt, capture_payment, ask, close_day,
            statement, create_contact, create_ledger, backup_only.
        tool_context: ADK session context (injected; not for the model).
    """
    del tool_context  # unused; signature keeps ADK injection consistent
    text = P.require_nonempty_str(goal_text, "goal_text")
    if isinstance(text, dict):
        return text
    if not isinstance(goal_class, str) or goal_class.strip() not in P.GOAL_CLASSES:
        return P.error(
            "goal_class must be one of: "
            + ", ".join(sorted(P.GOAL_CLASSES))
        )
    return P.make_proposal(
        "parse_goal",
        {"goalClass": goal_class.strip(), "notes": text[:500]},
        confirm_required=False,
    )


def _money_proposal(
    tool: str,
    contact_hint: str,
    amount_minor: Any,
    currency_code: str,
    note: str,
    item_name: str,
    ledger_id: str,
    ledger_hint: str,
    tool_context: Any,
) -> dict[str, Any]:
    ctx = P.get_daftar_context(tool_context)
    raw_hint = P.require_nonempty_str(contact_hint, "contact_hint")
    if isinstance(raw_hint, dict):
        return raw_hint
    hint, known_id = P.spoken_hint_and_id(ctx, contact_hint=raw_hint)
    if not hint:
        return P.error("contact_hint must be a spoken name, not a UUID")
    amount = P.require_amount_minor(amount_minor)
    if isinstance(amount, dict):
        return amount
    currency = P.resolve_currency(ctx, currency_code or "")
    amount = P.correct_zero_decimal_scale(
        ctx, currency, amount, contact_hint=hint
    )
    payload: dict[str, Any] = {
        "contactHint": hint,
        "amountMinor": amount,
        "currencyCode": currency,
    }
    contact_id = known_id or P.resolve_contact_id(ctx, contact_hint=hint)
    if contact_id:
        payload["contactId"] = contact_id
    if isinstance(item_name, str) and item_name.strip():
        payload["itemName"] = item_name.strip()
    if isinstance(note, str) and note.strip():
        payload["note"] = note.strip()
    lid = P.optional_uuid(ledger_id, "ledgerId") if ledger_id else None
    if isinstance(lid, dict):
        return lid
    if lid:
        payload["ledgerId"] = lid
    if isinstance(ledger_hint, str) and ledger_hint.strip():
        payload["ledgerHint"] = ledger_hint.strip()
    return P.make_proposal(tool, payload)


def propose_debt(
    contact_hint: str,
    amount_minor: int,
    currency_code: str = "",
    note: str = "",
    item_name: str = "",
    ledger_id: str = "",
    ledger_hint: str = "",
    tool_context: Any = None,
) -> dict[str, Any]:
    """Propose recording a debt (merchant is owed).

    One contact per call; call multiple times in parallel for compound intents.
    amount_minor is integer smallest currency unit ONLY (never float).
    CRITICAL examples:
      - YER + spoken 500 → amount_minor=500 (NOT 50000)
      - SAR/USD + spoken 500 → amount_minor=50000
    Empty currency_code uses daftarContext.defaultCurrency; if multi-currency
    is disabled, currency is forced to defaultCurrency.

    Spoken goods / صنف (juice, عصير) go in item_name, never note.
    Spoken remarks (he will pay Friday) go in note, never item_name.
    Never copy goods into note.

    Args:
        contact_hint: Name or fuzzy hint for contact resolution.
        amount_minor: Positive integer in smallest currency unit.
        currency_code: Optional ISO-like code; defaults from daftarContext.
        note: Optional remark (ملاحظة), not goods.
        item_name: Optional goods / صنف (Quick Add itemName).
        ledger_id: Optional ledger UUID.
        ledger_hint: Optional ledger name hint.
        tool_context: ADK session context (injected).
    """
    return _money_proposal(
        "propose_debt",
        contact_hint,
        amount_minor,
        currency_code,
        note,
        item_name,
        ledger_id,
        ledger_hint,
        tool_context,
    )


def propose_payment(
    contact_hint: str,
    amount_minor: int,
    currency_code: str = "",
    note: str = "",
    item_name: str = "",
    ledger_id: str = "",
    ledger_hint: str = "",
    tool_context: Any = None,
) -> dict[str, Any]:
    """Propose recording a payment. amount_minor is integer only (same rules as propose_debt).

    One contact per call; call multiple times in parallel for compound intents.
    Spoken goods / صنف go in item_name, never note. Remarks go in note.

    Args:
        contact_hint: Name or fuzzy hint for contact resolution.
        amount_minor: Positive integer in smallest currency unit.
        currency_code: Optional ISO-like code; defaults from daftarContext.
        note: Optional remark (ملاحظة), not goods.
        item_name: Optional goods / صنف (Quick Add itemName).
        ledger_id: Optional ledger UUID.
        ledger_hint: Optional ledger name hint.
        tool_context: ADK session context (injected).
    """
    return _money_proposal(
        "propose_payment",
        contact_hint,
        amount_minor,
        currency_code,
        note,
        item_name,
        ledger_id,
        ledger_hint,
        tool_context,
    )


def propose_create_contact(
    name: str,
    phone: str = "",
    ledger_id: str = "",
    tool_context: Any = None,
) -> dict[str, Any]:
    """Propose creating a contact.

    ledger_id is optional. When daftarContext has exactly one ledger, that id
    is filled in. When there are several, emit the proposal without ledgerId —
    the device Confirm Gate shows ledger chips. Never error on a missing
    ledger_id.

    Args:
        name: Contact display name.
        phone: Optional phone.
        ledger_id: Optional ledger UUID; device picks when omitted.
        tool_context: ADK session context (injected).
    """
    ctx = P.get_daftar_context(tool_context)
    name_v = P.require_nonempty_str(name, "name")
    if isinstance(name_v, dict):
        return name_v
    ledgers = P.ledgers(ctx)
    lid: Optional[str] = None
    if ledger_id and str(ledger_id).strip():
        checked = P.require_uuid(ledger_id, "ledgerId")
        if isinstance(checked, dict):
            return checked
        lid = checked
    elif len(ledgers) == 1:
        single = ledgers[0].get("id")
        if isinstance(single, str) and single.strip():
            checked = P.require_uuid(single, "ledgerId")
            if isinstance(checked, dict):
                return checked
            lid = checked
    payload: dict[str, Any] = {"name": name_v}
    if isinstance(phone, str) and phone.strip():
        payload["phone"] = phone.strip()
    if lid:
        payload["ledgerId"] = lid
    return P.make_proposal("propose_create_contact", payload)


def propose_create_ledger(
    name: str,
    ledger_type: str = "customers",
    tool_context: Any = None,
) -> dict[str, Any]:
    """Propose creating a ledger.

    Args:
        name: Ledger name.
        ledger_type: One of customers, suppliers, personal, custom.
        tool_context: ADK session context (injected).
    """
    del tool_context
    name_v = P.require_nonempty_str(name, "name")
    if isinstance(name_v, dict):
        return name_v
    lt = (ledger_type or "customers").strip()
    if lt not in P.LEDGER_TYPES:
        return P.error(
            "ledger_type must be one of: " + ", ".join(sorted(P.LEDGER_TYPES))
        )
    return P.make_proposal(
        "propose_create_ledger",
        {"name": name_v, "type": lt},
    )


def propose_closing_plan(
    step_titles: list[str],
    step_tools: Optional[list[str]] = None,
    local_day: str = "",
    tool_context: Any = None,
) -> dict[str, Any]:
    """Propose an ordered close-the-day plan (device executes after confirm).

    For close-day goals, pass ≥3 step_titles aligned with the device ritual
    (Drift day summary, Drive backup, aging, reminders/PDF prompts). Do not
    also call propose_whatsapp_drafts on close-the-day. local_day defaults to
    daftarContext.merchantLocalDay.

    Args:
        step_titles: Ordered human-readable step titles (min 1).
        step_tools: Optional parallel list of ProposalTool names per step.
        local_day: Optional YYYY-MM-DD; defaults from daftarContext.
        tool_context: ADK session context (injected).
    """
    ctx = P.get_daftar_context(tool_context)
    if not isinstance(step_titles, list) or len(step_titles) < 1:
        return P.error("step_titles must be a non-empty list of strings")
    tools_list = step_tools if isinstance(step_tools, list) else []
    steps: list[dict[str, Any]] = []
    for i, title in enumerate(step_titles):
        title_v = P.require_nonempty_str(title, f"step_titles[{i}]")
        if isinstance(title_v, dict):
            return title_v
        step: dict[str, Any] = {"title": title_v}
        if i < len(tools_list) and isinstance(tools_list[i], str) and tools_list[i].strip():
            t = tools_list[i].strip()
            if t not in P.PROPOSAL_TOOLS:
                return P.error(f"step_tools[{i}] is not a valid ProposalTool: {t}")
            step["tool"] = t
        steps.append(step)
    payload: dict[str, Any] = {"steps": steps}
    day = local_day.strip() if isinstance(local_day, str) else ""
    if not day:
        day = P.merchant_local_day(ctx) or ""
    if day:
        payload["localDay"] = day
    return P.make_proposal("propose_closing_plan", payload)


def propose_whatsapp_drafts(
    contact_ids: list[str],
    bodies: list[str],
    tone: str = "polite",
    tones: Optional[list[str]] = None,
    tool_context: Any = None,
) -> dict[str, Any]:
    """Propose WhatsApp reminder drafts (prepare only — no send).

    Call only for an explicit prepare-reminders ask without close-the-day.
    Parallel lists: contact_ids and bodies must be equal length (≥1).
    Optional tones list (same length) overrides the default tone per draft.
    contact_ids must be UUIDs, or display names resolvable via voiceHints.

    Args:
        contact_ids: Contact UUIDs (or resolvable names).
        bodies: Message bodies (non-empty).
        tone: Default tone when tones is omitted (e.g. polite, firm, brief).
        tones: Optional per-draft tones.
        tool_context: ADK session context (injected).
    """
    ctx = P.get_daftar_context(tool_context)
    if not isinstance(contact_ids, list) or not isinstance(bodies, list):
        return P.error("contact_ids and bodies must be lists")
    if len(contact_ids) < 1:
        return P.error("contact_ids must contain at least one entry")
    if len(contact_ids) != len(bodies):
        return P.error("contact_ids and bodies must have the same length")
    tone_list: list[str] = []
    if isinstance(tones, list):
        if len(tones) != len(contact_ids):
            return P.error("tones must match contact_ids length when provided")
        tone_list = [str(t) for t in tones]
    else:
        default_tone = tone.strip() if isinstance(tone, str) and tone.strip() else "polite"
        tone_list = [default_tone] * len(contact_ids)

    drafts: list[dict[str, Any]] = []
    for i, raw_id in enumerate(contact_ids):
        body_v = P.require_nonempty_str(bodies[i], f"bodies[{i}]")
        if isinstance(body_v, dict):
            return body_v
        tone_v = P.require_nonempty_str(tone_list[i], f"tones[{i}]")
        if isinstance(tone_v, dict):
            return tone_v
        cid: str | dict[str, Any]
        if P.is_uuid(raw_id):
            cid = str(raw_id).strip()
        else:
            cid = P.resolve_contact_id_or_error(
                ctx,
                contact_id="",
                contact_hint=str(raw_id) if raw_id is not None else "",
            )
        if isinstance(cid, dict):
            return cid
        drafts.append({"contactId": cid, "tone": tone_v, "body": body_v})
    return P.make_proposal("propose_whatsapp_drafts", {"drafts": drafts})


def propose_statement(
    contact_id: str = "",
    contact_hint: str = "",
    ledger_id: str = "",
    tool_context: Any = None,
) -> dict[str, Any]:
    """Propose generating a customer statement PDF.

    One contact per call; call multiple times in parallel for compound intents.
    Pass contact_id (UUID) or contact_hint. Unresolved hints still emit a
    proposal — the device resolves from Drift. Never error on a miss.

    Args:
        contact_id: Contact UUID when known.
        contact_hint: Spoken or typed name — never a UUID. Device FTS when
            the UUID is missing. Backfilled from voiceHints.displayName when
            only contact_id is passed.
        ledger_id: Optional ledger UUID.
        tool_context: ADK session context (injected).
    """
    ctx = P.get_daftar_context(tool_context)
    raw_hint = contact_hint.strip() if isinstance(contact_hint, str) else ""
    raw_id = contact_id.strip() if isinstance(contact_id, str) else ""
    if raw_id:
        checked = P.require_uuid(raw_id, "contactId")
        if isinstance(checked, dict):
            return checked
        raw_id = checked
    hint, cid = P.spoken_hint_and_id(
        ctx, contact_hint=raw_hint, contact_id=raw_id
    )
    if not cid:
        resolved = P.resolve_contact_id(ctx, contact_hint=hint)
        if resolved:
            cid = resolved
    if not cid and not hint:
        return P.error("contactId or contact_hint is required")
    payload: dict[str, Any] = {}
    if cid:
        payload["contactId"] = cid
    if hint:
        payload["contactHint"] = hint
    if ledger_id and str(ledger_id).strip():
        lid = P.require_uuid(ledger_id, "ledgerId")
        if isinstance(lid, dict):
            return lid
        payload["ledgerId"] = lid
    return P.make_proposal("propose_statement", payload)


# Frozen through Gate 5 (§5.3). Do not append FunctionTools without a Gate 4
# regression: send set ≤20, PDF ranked Top 5, SMTP 250, no allUsers, no second
# Cloud Run. WhatsApp is leftover Hybrid E — not a new lead tool.
ALL_TOOLS = [
    parse_goal,
    propose_debt,
    propose_payment,
    propose_create_contact,
    propose_create_ledger,
    propose_closing_plan,
    propose_whatsapp_drafts,
    propose_statement,
]
