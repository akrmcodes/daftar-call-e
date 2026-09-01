"""Unit tests for Stage 1.2 proposal tools (no Vertex / Cloud Run)."""

from __future__ import annotations

import copy
import uuid
from pathlib import Path
from typing import Any

import pytest
import yaml
from jsonschema import Draft202012Validator

from closing_agent import proposal as P
from closing_agent.tools import (
    parse_goal,
    propose_closing_plan,
    propose_create_contact,
    propose_create_ledger,
    propose_debt,
    propose_payment,
    propose_statement,
    propose_whatsapp_drafts,
)

OPENAPI_PATH = Path(__file__).resolve().parents[1] / "openapi.yaml"
LEDGER_A = "11111111-1111-4111-8111-111111111111"
LEDGER_B = "22222222-2222-4222-8222-222222222222"
CONTACT_MOHAMED = "33333333-3333-4333-8333-333333333333"
CONTACT_AHMED = "44444444-4444-4444-8444-444444444444"


class FakeToolContext:
    def __init__(self, daftar_context: dict[str, Any] | None = None) -> None:
        self.state = {}
        if daftar_context is not None:
            self.state["daftarContext"] = daftar_context


def _base_ctx(**overrides: Any) -> dict[str, Any]:
    ctx: dict[str, Any] = {
        "correlationId": str(uuid.uuid4()),
        "locale": "ar",
        "merchantLocalDay": "2026-08-13",
        "ledgers": [{"id": LEDGER_A, "name": "Customers"}],
        "voiceHints": [
            {
                "contactId": CONTACT_MOHAMED,
                "displayName": "Mohamed",
                "phone": "+967700000000",
            }
        ],
        "isMultiCurrencyEnabled": False,
        "defaultCurrency": "YER",
        "goalText": "test",
    }
    ctx.update(overrides)
    return ctx


@pytest.fixture(scope="module")
def schemas() -> dict[str, Any]:
    with OPENAPI_PATH.open(encoding="utf-8") as f:
        return yaml.safe_load(f)["components"]["schemas"]


def _inline_refs(
    node: Any,
    schemas: dict[str, Any],
    stack: frozenset[str] = frozenset(),
) -> Any:
    """Recursively replace ``#/components/schemas/X`` with inlined copies."""
    if isinstance(node, dict):
        if set(node.keys()) == {"$ref"}:
            ref = node["$ref"]
            prefix = "#/components/schemas/"
            if not isinstance(ref, str) or not ref.startswith(prefix):
                return node
            name = ref[len(prefix) :]
            if name in stack:
                return {"type": "object"}
            return _inline_refs(
                copy.deepcopy(schemas[name]),
                schemas,
                stack | {name},
            )
        return {k: _inline_refs(v, schemas, stack) for k, v in node.items()}
    if isinstance(node, list):
        return [_inline_refs(x, schemas, stack) for x in node]
    return node


def _validate_payload(
    schemas: dict[str, Any],
    schema_name: str,
    payload: dict[str, Any],
) -> None:
    schema = _inline_refs(copy.deepcopy(schemas[schema_name]), schemas)
    Draft202012Validator(schema).validate(payload)


def _assert_proposal(result: dict[str, Any]) -> None:
    assert P.is_proposal(result)
    uuid.UUID(result["proposalId"])
    assert "confirmRequired" in result
    assert result["tool"] in P.PROPOSAL_TOOLS


def test_parse_goal_happy(schemas: dict[str, Any]) -> None:
    result = parse_goal("اقفل يومي", "close_day")
    assert result["confirmRequired"] is False
    assert result["tool"] == "parse_goal"
    _validate_payload(schemas, "ParseGoalPayload", result["payload"])
    _assert_proposal(result)


def test_parse_goal_invalid_class() -> None:
    result = parse_goal("hi", "not_a_class")
    assert result["status"] == "error"
    assert "proposalId" not in result


def test_propose_debt_yer_500(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_debt("Mohamed", 500, tool_context=ctx)
    assert result["tool"] == "propose_debt"
    assert result["confirmRequired"] is True
    assert result["payload"]["amountMinor"] == 500
    assert result["payload"]["currencyCode"] == "YER"
    assert result["payload"]["contactId"] == CONTACT_MOHAMED
    _validate_payload(schemas, "ProposeDebtPayload", result["payload"])
    _assert_proposal(result)


def test_propose_debt_item_name_is_goods_not_note(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_debt(
        "Mohamed", 500, item_name="juice", tool_context=ctx
    )
    assert result["payload"]["itemName"] == "juice"
    assert "note" not in result["payload"]
    _validate_payload(schemas, "ProposeDebtPayload", result["payload"])


def test_propose_debt_arabic_item_name(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_debt(
        "Mohamed", 500, item_name="عصير", tool_context=ctx
    )
    assert result["payload"]["itemName"] == "عصير"
    assert "note" not in result["payload"]
    _validate_payload(schemas, "ProposeDebtPayload", result["payload"])


def test_propose_debt_note_is_remark_not_goods(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_debt(
        "Mohamed", 500, note="he will pay Friday", tool_context=ctx
    )
    assert result["payload"]["note"] == "he will pay Friday"
    assert "itemName" not in result["payload"]
    _validate_payload(schemas, "ProposeDebtPayload", result["payload"])


def test_propose_payment_item_name(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_payment(
        "Mohamed", 200, item_name="juice", tool_context=ctx
    )
    assert result["payload"]["itemName"] == "juice"
    assert "note" not in result["payload"]
    _validate_payload(schemas, "ProposePaymentPayload", result["payload"])


def test_propose_debt_yer_corrects_100x_mis_scale() -> None:
    """Model often passes 50000 for spoken YER 500 — tool must correct."""
    ctx = FakeToolContext(_base_ctx(goalText="Mohamed owes 500"))
    result = propose_debt("Mohamed", 50000, tool_context=ctx)
    assert result["payload"]["amountMinor"] == 500
    assert result["payload"]["currencyCode"] == "YER"


def test_propose_payment_usd_scales_spoken_500() -> None:
    """Gemini often passes 500 as minor on USD; spoken 500 is $500.00."""
    ctx = FakeToolContext(
        _base_ctx(
            goalText="Mohamed paid 500",
            defaultCurrency="USD",
        )
    )
    result = propose_payment("Mohamed", 500, tool_context=ctx)
    assert result["payload"]["amountMinor"] == 50000
    assert result["payload"]["currencyCode"] == "USD"


def test_propose_debt_usd_ahmed_200() -> None:
    ctx = FakeToolContext(
        _base_ctx(
            goalText="Ahmed owes 200",
            defaultCurrency="USD",
            voiceHints=[
                {
                    "contactId": CONTACT_AHMED,
                    "displayName": "Ahmed",
                    "phone": "+967700000002",
                }
            ],
        )
    )
    result = propose_debt("Ahmed", 200, tool_context=ctx)
    assert result["payload"]["amountMinor"] == 20000
    assert result["payload"]["currencyCode"] == "USD"


def test_propose_debt_yer_word_thousand_snaps_from_10000() -> None:
    ctx = FakeToolContext(_base_ctx(goalText="Mohamed owes one thousand Riyals"))
    result = propose_debt("Mohamed", 10000, tool_context=ctx)
    assert result["payload"]["amountMinor"] == 1000


def test_propose_debt_yer_arabic_thousand_snaps_from_10000() -> None:
    ctx = FakeToolContext(_base_ctx(goalText="على محمد ألف ريال"))
    result = propose_debt("Mohamed", 10000, tool_context=ctx)
    assert result["payload"]["amountMinor"] == 1000


def test_propose_debt_spoken_10000_digits_left_alone() -> None:
    ctx = FakeToolContext(_base_ctx(goalText="Mohamed owes 10000"))
    result = propose_debt("Mohamed", 10000, tool_context=ctx)
    assert result["payload"]["amountMinor"] == 10000


def test_propose_debt_sar_word_thousand_snaps_from_1000000() -> None:
    ctx = FakeToolContext(
        _base_ctx(
            goalText="one thousand Riyals",
            defaultCurrency="SAR",
            isMultiCurrencyEnabled=True,
        )
    )
    result = propose_debt("Mohamed", 1000000, currency_code="SAR", tool_context=ctx)
    assert result["payload"]["amountMinor"] == 100000
    assert result["payload"]["currencyCode"] == "SAR"


@pytest.mark.parametrize(
    ("goal", "spoken"),
    [
        ("Mohammed paid two hundred Riyals", 200),
        ("Mohammed paid 2 hundred Riyals", 200),
        ("two hundreds", 200),
        ("two thousand", 2000),
        ("Mohamed owes one thousand Riyals", 1000),
        ("2k", 2000),
        ("سدد مائتين ريال", 200),
        ("سدد مئتين ريال", 200),
        ("سدد ميتين ريال", 200),
        ("خمسمئة", 500),
        ("خمس مئة", 500),
        ("مية", 100),
        ("مائة وخمسين", 150),
        ("خمسين", 50),
        ("على محمد ألف ريال", 1000),
        ("عليه ٢٠٠ ريال", 200),
        ("عليه ١٬٠٠٠ ريال", 1000),
        ("500 riyals on 14", 500),
        ("Mohamed owes 10000", 10000),
        ("٢ مئة", 200),
    ],
)
def test_parse_spoken_major_vectors(goal: str, spoken: int) -> None:
    assert P.parse_spoken_major(goal) == spoken


@pytest.mark.parametrize(
    ("goal", "currency", "amount_minor", "expected"),
    [
        ("Mohammed paid two hundred Riyals", "YER", 20000, 200),
        ("Mohammed paid 2 hundred Riyals", "YER", 20000, 200),
        ("two hundreds", "YER", 20000, 200),
        ("two thousand", "YER", 20000, 2000),
        ("Mohamed owes one thousand Riyals", "YER", 10000, 1000),
        ("على محمد ألف ريال", "YER", 10000, 1000),
        ("سدد مائتين ريال", "YER", 20000, 200),
        ("سدد مئتين ريال", "YER", 20000, 200),
        ("سدد ميتين ريال", "YER", 20000, 200),
        ("خمسمئة", "YER", 50000, 500),
        ("خمس مئة", "YER", 50000, 500),
        ("مية", "YER", 10000, 100),
        ("مائة وخمسين", "YER", 15000, 150),
        ("خمسين", "YER", 5000, 50),
        ("عليه ٢٠٠ ريال", "YER", 20000, 200),
        ("500 riyals on 14", "YER", 50000, 500),
        ("Mohamed owes 10000", "YER", 10000, 10000),
        ("Mohamed owes 500", "YER", 50000, 500),
        ("Mohamed owes 500", "YER", 500, 500),
        ("Mohamed paid 500", "USD", 500, 50000),
        ("Mohamed paid 500", "USD", 50000, 50000),
        ("Mohamed owes 500 sugar", "USD", 500, 50000),
        ("Ahmed owes 200", "USD", 200, 20000),
        ("محمد سدد 500", "USD", 500, 50000),
        ("أحمد عليه 200", "USD", 200, 20000),
        ("one thousand Riyals", "YER", 7, 7),
        ("two hundred", "SAR", 20000, 20000),
        ("one thousand Riyals", "SAR", 1000000, 100000),
    ],
)
def test_spoken_amount_snap_vectors(
    goal: str,
    currency: str,
    amount_minor: int,
    expected: int,
) -> None:
    ctx = FakeToolContext(
        _base_ctx(
            goalText=goal,
            defaultCurrency=currency,
            isMultiCurrencyEnabled=True,
        )
    )
    result = propose_debt(
        "Mohamed",
        amount_minor,
        currency_code=currency,
        tool_context=ctx,
    )
    assert result["payload"]["amountMinor"] == expected


def test_propose_debt_compound_english_two_hints_snap_each() -> None:
    ctx = FakeToolContext(
        _base_ctx(
            goalText="Ahmed 500 and Mohamed 300",
            voiceHints=[
                {
                    "contactId": CONTACT_AHMED,
                    "displayName": "Ahmed",
                    "phone": "+967700000001",
                },
                {
                    "contactId": CONTACT_MOHAMED,
                    "displayName": "Mohamed",
                    "phone": "+967700000000",
                },
            ],
        )
    )
    first = propose_debt("Ahmed", 50000, tool_context=ctx)
    second = propose_debt("Mohamed", 30000, tool_context=ctx)
    assert first["payload"]["amountMinor"] == 500
    assert second["payload"]["amountMinor"] == 300


def test_propose_debt_compound_arabic_two_hints_snap_each() -> None:
    ctx = FakeToolContext(
        _base_ctx(
            goalText="أحمد 500 ومحمد 300",
            voiceHints=[
                {
                    "contactId": CONTACT_AHMED,
                    "displayName": "أحمد",
                    "phone": "+967700000001",
                },
                {
                    "contactId": CONTACT_MOHAMED,
                    "displayName": "محمد",
                    "phone": "+967700000000",
                },
            ],
        )
    )
    first = propose_debt("أحمد", 50000, tool_context=ctx)
    second = propose_debt("محمد", 30000, tool_context=ctx)
    assert first["payload"]["amountMinor"] == 500
    assert second["payload"]["amountMinor"] == 300


def test_propose_debt_rejects_float() -> None:
    result = propose_debt(
        "Mohamed",
        500.0,  # type: ignore[arg-type]
        tool_context=FakeToolContext(_base_ctx()),
    )
    assert result["status"] == "error"


def test_propose_debt_rejects_bool() -> None:
    result = propose_debt(
        "Mohamed",
        True,  # type: ignore[arg-type]
        tool_context=FakeToolContext(_base_ctx()),
    )
    assert result["status"] == "error"


def test_propose_debt_forces_default_currency() -> None:
    ctx = FakeToolContext(
        _base_ctx(isMultiCurrencyEnabled=False, defaultCurrency="YER")
    )
    result = propose_debt("Mohamed", 500, currency_code="SAR", tool_context=ctx)
    assert result["payload"]["currencyCode"] == "YER"


def test_propose_payment_multi_currency_allows_sar(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(
        _base_ctx(isMultiCurrencyEnabled=True, defaultCurrency="YER")
    )
    result = propose_payment(
        "Mohamed", 50000, currency_code="SAR", tool_context=ctx
    )
    assert result["payload"]["currencyCode"] == "SAR"
    assert result["payload"]["amountMinor"] == 50000
    _validate_payload(schemas, "ProposePaymentPayload", result["payload"])


def test_propose_create_contact_multi_ledger_omits_id() -> None:
    ctx = FakeToolContext(
        _base_ctx(
            ledgers=[
                {"id": LEDGER_A, "name": "A"},
                {"id": LEDGER_B, "name": "B"},
            ]
        )
    )
    result = propose_create_contact("Ali", tool_context=ctx)
    assert "proposalId" in result
    assert "ledgerId" not in result["payload"]
    assert result["payload"]["name"] == "Ali"


def test_propose_create_contact_multi_ledger_with_id(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(
        _base_ctx(
            ledgers=[
                {"id": LEDGER_A, "name": "A"},
                {"id": LEDGER_B, "name": "B"},
            ]
        )
    )
    result = propose_create_contact(
        "Ali", phone="+9677", ledger_id=LEDGER_B, tool_context=ctx
    )
    assert result["payload"]["ledgerId"] == LEDGER_B
    assert result["confirmRequired"] is True
    _validate_payload(schemas, "ProposeCreateContactPayload", result["payload"])


def test_propose_create_contact_single_ledger_defaults(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_create_contact("Ali", tool_context=ctx)
    assert result["payload"]["ledgerId"] == LEDGER_A
    _validate_payload(schemas, "ProposeCreateContactPayload", result["payload"])


def test_propose_create_ledger(schemas: dict[str, Any]) -> None:
    result = propose_create_ledger("Suppliers", ledger_type="suppliers")
    assert result["payload"]["type"] == "suppliers"
    _validate_payload(schemas, "ProposeCreateLedgerPayload", result["payload"])


def test_propose_create_ledger_bad_type() -> None:
    result = propose_create_ledger("X", ledger_type="warehouse")
    assert result["status"] == "error"


def test_propose_closing_plan_valid(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_closing_plan(
        [
            "Drift day summary",
            "Drive backup",
            "Aging review",
        ],
        step_tools=[
            "parse_goal",
            "propose_create_ledger",
            "propose_whatsapp_drafts",
        ],
        tool_context=ctx,
    )
    assert result["payload"]["localDay"] == "2026-08-13"
    assert len(result["payload"]["steps"]) == 3
    assert result["confirmRequired"] is True
    _validate_payload(schemas, "ProposeClosingPlanPayload", result["payload"])


def test_propose_whatsapp_drafts(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_whatsapp_drafts(
        [CONTACT_MOHAMED],
        ["مرحبا محمد، الرصيد المستحق ..."],
        tone="polite",
        tool_context=ctx,
    )
    assert result["payload"]["drafts"][0]["contactId"] == CONTACT_MOHAMED
    _validate_payload(schemas, "ProposeWhatsappDraftsPayload", result["payload"])


def test_propose_whatsapp_resolves_hint() -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_whatsapp_drafts(
        ["Mohamed"],
        ["Hello Mohamed"],
        tool_context=ctx,
    )
    assert result["payload"]["drafts"][0]["contactId"] == CONTACT_MOHAMED


def test_propose_whatsapp_length_mismatch() -> None:
    result = propose_whatsapp_drafts(
        [CONTACT_MOHAMED],
        [],
        tool_context=FakeToolContext(_base_ctx()),
    )
    assert result["status"] == "error"


def test_propose_statement(schemas: dict[str, Any]) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_statement(contact_hint="Mohamed", tool_context=ctx)
    assert result["payload"]["contactId"] == CONTACT_MOHAMED
    assert result["payload"]["contactHint"] == "Mohamed"
    _validate_payload(schemas, "ProposeStatementPayload", result["payload"])


def test_propose_statement_backfills_hint_from_voice_hints(
    schemas: dict[str, Any],
) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_statement(contact_id=CONTACT_MOHAMED, tool_context=ctx)
    assert result["payload"]["contactId"] == CONTACT_MOHAMED
    assert result["payload"]["contactHint"] == "Mohamed"
    _validate_payload(schemas, "ProposeStatementPayload", result["payload"])


def test_propose_statement_uuid_as_hint_becomes_spoken_name(
    schemas: dict[str, Any],
) -> None:
    ctx = FakeToolContext(_base_ctx())
    result = propose_statement(contact_hint=CONTACT_MOHAMED, tool_context=ctx)
    assert result["payload"]["contactId"] == CONTACT_MOHAMED
    assert result["payload"]["contactHint"] == "Mohamed"
    _validate_payload(schemas, "ProposeStatementPayload", result["payload"])


def test_propose_statement_unresolved_hint_is_proposal(
    schemas: dict[str, Any],
) -> None:
    result = propose_statement(
        contact_hint="أحمد عبد الله",
        tool_context=FakeToolContext(_base_ctx()),
    )
    assert "proposalId" in result
    assert result["payload"]["contactHint"] == "أحمد عبد الله"
    assert "contactId" not in result["payload"]
    _validate_payload(schemas, "ProposeStatementPayload", result["payload"])


def test_propose_statement_folds_spaced_abd_name(
    schemas: dict[str, Any],
) -> None:
    ahmed_id = "44444444-4444-4444-8444-444444444444"
    ctx = FakeToolContext(
        _base_ctx(
            voiceHints=[
                {
                    "contactId": ahmed_id,
                    "displayName": "أحمد عبدالله",
                    "phone": "+967700000001",
                }
            ]
        )
    )
    result = propose_statement(
        contact_hint="أحمد عبد الله",
        tool_context=ctx,
    )
    assert result["payload"]["contactId"] == ahmed_id
    _validate_payload(schemas, "ProposeStatementPayload", result["payload"])


def test_confirm_required_matrix() -> None:
    ctx = FakeToolContext(_base_ctx())
    assert parse_goal("x", "ask")["confirmRequired"] is False
    assert propose_debt("Mohamed", 1, tool_context=ctx)["confirmRequired"] is True
    assert propose_create_ledger("L")["confirmRequired"] is True
