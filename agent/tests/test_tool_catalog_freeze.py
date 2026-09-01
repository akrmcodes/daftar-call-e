"""§5.3 freeze: Gate 4 ADK catalog is eight tools. No new FunctionTools."""

from __future__ import annotations

from pathlib import Path

import yaml

from closing_agent.tools import ALL_TOOLS

OPENAPI_PATH = Path(__file__).resolve().parents[1] / "openapi.yaml"

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


def test_all_tools_frozen_to_gate4_catalog() -> None:
    names = [fn.__name__ for fn in ALL_TOOLS]
    assert len(names) == 8
    assert len(set(names)) == 8
    assert set(names) == FROZEN_PROPOSAL_TOOLS


def test_openapi_proposal_tool_enum_matches_all_tools() -> None:
    with OPENAPI_PATH.open(encoding="utf-8") as f:
        spec = yaml.safe_load(f)
    enum = spec["components"]["schemas"]["ProposalTool"]["enum"]
    assert isinstance(enum, list)
    assert len(enum) == 8
    assert set(enum) == FROZEN_PROPOSAL_TOOLS
