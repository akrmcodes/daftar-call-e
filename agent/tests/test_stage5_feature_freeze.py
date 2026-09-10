"""§5.5 freeze: two HITL triggers, no inbound/WhatsApp lead, no Gemini Live."""

from __future__ import annotations

from pathlib import Path
from typing import get_args

import yaml

from calls.schemas import Trigger

AGENT_ROOT = Path(__file__).resolve().parents[1]
OPENAPI_PATH = AGENT_ROOT / "openapi.yaml"
SCAN_DIRS = (AGENT_ROOT / "calls", AGENT_ROOT / "closing_agent")
FROZEN_TRIGGERS = frozenset({"closeDay", "creditLimit"})
LIVE_NEEDLES = (
    "run_live",
    "StreamingMode.BIDI",
    "bidiGenerateContent",
    "LiveRequestQueue",
)
PATH_NEEDLES = ("webhook", "whatsapp", "inbound", "ivr")


def _spec() -> dict:
    return yaml.safe_load(OPENAPI_PATH.read_text(encoding="utf-8"))


def test_openapi_trigger_enum_is_close_day_or_credit_limit() -> None:
    spec = _spec()
    enum = spec["components"]["schemas"]["PlanBatchRequest"]["properties"]["trigger"][
        "enum"
    ]
    assert isinstance(enum, list)
    assert set(enum) == FROZEN_TRIGGERS
    assert len(enum) == 2


def test_pydantic_trigger_literal_matches_openapi() -> None:
    assert set(get_args(Trigger)) == FROZEN_TRIGGERS


def test_calls_and_closing_agent_have_no_live_api_surface() -> None:
    hits: list[str] = []
    for root in SCAN_DIRS:
        for path in root.rglob("*.py"):
            text = path.read_text(encoding="utf-8")
            for needle in LIVE_NEEDLES:
                if needle in text:
                    hits.append(f"{path.relative_to(AGENT_ROOT)}:{needle}")
    assert hits == []


def test_openapi_paths_have_no_inbound_ivr_whatsapp_or_webhook() -> None:
    paths = _spec().get("paths") or {}
    assert "/v1/calls/plan-batch" in paths
    assert "/v1/calls/run-batch" in paths
    assert "/v1/calls/{runId}" in paths
    assert "/v1/calls/inbound" not in paths
    for path in paths:
        lowered = str(path).lower()
        for needle in PATH_NEEDLES:
            assert needle not in lowered, f"{path} contains {needle}"
