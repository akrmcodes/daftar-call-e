"""String contract: capture/close skip parse_goal; compound = parallel calls."""

from __future__ import annotations

from pathlib import Path

_AGENT_PY = Path(__file__).resolve().parents[1] / "closing_agent" / "agent.py"
_TOOLS_PY = Path(__file__).resolve().parents[1] / "closing_agent" / "tools.py"


def _instruction() -> str:
    source = _AGENT_PY.read_text(encoding="utf-8")
    marker = 'INSTRUCTION = """'
    start = source.index(marker) + len(marker)
    end = source.index('"""', start)
    return source[start:end]


def test_instruction_forbids_parse_goal_on_capture_and_close() -> None:
    instruction = _instruction()
    assert "Optional: call parse_goal" not in instruction
    lowered = instruction.lower()
    assert "do not call parse_goal" in lowered
    assert "one step" not in lowered
    assert "propose_debt" in lowered
    assert "propose_payment" in lowered
    assert "propose_closing_plan" in lowered
    assert "propose_create_contact" in lowered
    assert "propose_create_ledger" in lowered
    assert "propose_statement" in lowered
    assert "ask" in lowered
    assert "do not invent" in lowered or "drift" in lowered
    assert "backup_only" in lowered
    assert "ambiguous" in lowered
    assert "open the customer list" in lowered
    assert "sort balances" in lowered
    assert "leave the agent" in lowered
    assert "add them first" in lowered
    assert "missing" in lowered


def test_instruction_create_contact_defers_ledger_to_device() -> None:
    instruction = _instruction()
    lowered = instruction.lower()
    assert "ledger_id is optional" in lowered
    assert "pick a book" in lowered
    assert "already registered" in lowered
    assert "list of accounts" in lowered
    assert "ledger_id required if multi-ledger" not in lowered


def test_instruction_goods_go_in_item_name_not_note() -> None:
    instruction = _instruction()
    lowered = instruction.lower()
    assert "item_name only" in lowered
    assert "never put goods in note" in lowered
    assert "never duplicate" in lowered
    assert "صنف" in instruction
    assert "juice" in lowered


def test_instruction_locks_compound_localday_and_hybrid_e() -> None:
    instruction = _instruction()
    lowered = instruction.lower()
    assert "multiple function calls" in lowered
    assert "same turn" in lowered
    assert "do not drop the second action" in lowered
    assert "do **not** also call propose_whatsapp_drafts" in instruction.lower() or (
        "do not also call propose_whatsapp_drafts" in lowered
    )
    assert "merchantlocalday" in lowered
    assert "hybrid e" in lowered
    assert "model c" in lowered
    assert "30/60/90" in lowered
    assert "confirm gate" in lowered
    assert "سكر اليوم" in instruction
    assert "اقفل يومي" in instruction
    assert "كشف حساب" in instruction


def test_instruction_defers_ranked_send_split_to_device() -> None:
    instruction = _instruction()
    lowered = instruction.lower()
    assert "narrate the split" not in lowered
    assert "ritual ui" in lowered
    assert "device aging ranks" in lowered
    assert "do **not** pick contact ids" in instruction.lower() or (
        "do not pick contact ids" in lowered
    )
    assert "do **not** claim email was sent" in instruction.lower() or (
        "do not claim email was sent" in lowered
    )
    assert "no send-email tool" in lowered
    assert "confirm & send statements" in lowered
    assert "gmail smtp" in lowered
    assert "sent email" in lowered
    assert "hybrid e" in lowered


def test_instruction_clerk_voice_contract() -> None:
    instruction = _instruction()
    lowered = instruction.lower()
    assert "desk clerk" in lowered
    assert "contact_hint is always the spoken name" in lowered
    assert "never a uuid in contact_hint" in lowered
    assert "markdown" in lowered
    assert "you asked me" in lowered
    assert "i have proposed" in lowered
    assert "verbatim transcript" in lowered
    assert "speak in arabic" in lowered
    assert "تحدث بالعربية" in instruction
    assert "spoken essay" in lowered
    assert "never enumerate steps" in lowered
    assert "device owns spoken ack" in lowered


def test_instruction_treats_inline_audio_as_utterance() -> None:
    instruction = _instruction()
    lowered = instruction.lower()
    assert "__voice__" in instruction
    assert "inline:" in instruction
    assert "verbatim transcript" in lowered
    assert "not live api" in lowered
    assert "audio is the utterance" in lowered


def test_tool_docstrings_require_one_contact_per_parallel_call() -> None:
    source = _TOOLS_PY.read_text(encoding="utf-8")
    assert "one contact per call" in source.lower()
    assert "compound" in source.lower()
    assert "in parallel" in source.lower()


def test_parse_goal_remains_in_all_tools_source() -> None:
    """Keep parse_goal in ALL_TOOLS (OpenAPI / §1.2). Do not delete the tool."""
    source = _TOOLS_PY.read_text(encoding="utf-8")
    assert "parse_goal" in source
    assert "ALL_TOOLS" in source
