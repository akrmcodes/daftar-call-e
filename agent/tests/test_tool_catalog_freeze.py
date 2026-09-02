"""§5.3 freeze: Gate 4 ADK catalog is eight tools. No new FunctionTools."""

from __future__ import annotations

from pathlib import Path

import yaml

from closing_agent.tools import ALL_TOOLS

AGENT_ROOT = Path(__file__).resolve().parents[1]
OPENAPI_PATH = AGENT_ROOT / "openapi.yaml"
CLOSING_AGENT_DIR = AGENT_ROOT / "closing_agent"
MAIN_PATH = AGENT_ROOT / "main.py"

FROZEN_PROPOSAL_TOOLS = frozenset(
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

BANNED_CALL_TOOLS = ("plan_call", "run_call", "get_call_run", "propose_call")


def test_all_tools_frozen_to_gate4_catalog() -> None:
    names = [fn.__name__ for fn in ALL_TOOLS]
    assert len(names) == 8
    assert len(set(names)) == 8
    assert set(names) == FROZEN_PROPOSAL_TOOLS
    joined = " ".join(names)
    for needle in BANNED_CALL_TOOLS:
        assert needle not in names
        assert needle not in joined


def test_openapi_proposal_tool_enum_matches_all_tools() -> None:
    with OPENAPI_PATH.open(encoding="utf-8") as f:
        spec = yaml.safe_load(f)
    enum = spec["components"]["schemas"]["ProposalTool"]["enum"]
    assert isinstance(enum, list)
    assert len(enum) == 8
    assert set(enum) == FROZEN_PROPOSAL_TOOLS


def test_closing_agent_has_no_call_function_tools() -> None:
    hits: list[str] = []
    for path in CLOSING_AGENT_DIR.rglob("*.py"):
        text = path.read_text(encoding="utf-8")
        for needle in BANNED_CALL_TOOLS:
            if needle in text:
                hits.append(f"{path.name}:{needle}")
    assert hits == []


def test_calls_router_is_fastapi_include_not_a_tool() -> None:
    src = MAIN_PATH.read_text(encoding="utf-8")
    assert "from calls.router import router as calls_router" in src
    assert "app.include_router(calls_router)" in src
    names = [fn.__name__ for fn in ALL_TOOLS]
    assert "plan_batch" not in names
    assert "run_batch" not in names
    assert "get_call" not in names
