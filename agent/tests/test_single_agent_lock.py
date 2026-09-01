"""Contest lock: one ADK LlmAgent root — no SequentialAgent / AgentTool graph."""

from __future__ import annotations

import ast
from pathlib import Path

from closing_agent.agent import root_agent
from google.adk.agents.llm_agent import Agent

AGENT_PY = Path(__file__).resolve().parents[1] / "closing_agent" / "agent.py"
BANNED_IMPORTS = frozenset(
    {
        "SequentialAgent",
        "ParallelAgent",
        "LoopAgent",
        "AgentTool",
    }
)


def test_root_agent_is_single_llm_agent() -> None:
    assert isinstance(root_agent, Agent)
    assert root_agent.name == "closing_agent"
    assert len(root_agent.tools) == 8


def test_agent_py_does_not_import_multi_agent_primitives() -> None:
    tree = ast.parse(AGENT_PY.read_text(encoding="utf-8"))
    imported: set[str] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom):
            for alias in node.names:
                imported.add(alias.name)
        elif isinstance(node, ast.Import):
            for alias in node.names:
                imported.add(alias.name.split(".")[-1])
    assert imported.isdisjoint(BANNED_IMPORTS), (
        f"Banned multi-agent imports in agent.py: {imported & BANNED_IMPORTS}"
    )


def test_agent_py_root_agent_has_no_sub_agents_kwarg() -> None:
    source = AGENT_PY.read_text(encoding="utf-8")
    assert "sub_agents" not in source
    assert "AgentTool" not in source
    assert "SequentialAgent" not in source
