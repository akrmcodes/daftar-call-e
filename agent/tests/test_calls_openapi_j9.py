"""Stage 1.4 / 5.1 — OpenAPI 2.8.0 matches J.9 plan / run / get. Catalog stays eight."""

from __future__ import annotations

from pathlib import Path

import yaml

AGENT_ROOT = Path(__file__).resolve().parents[1]
OPENAPI_PATH = AGENT_ROOT / "openapi.yaml"
SMOKE_PATH = AGENT_ROOT / "scripts" / "smoke_calls_plan_run.py"

J9_OUTCOMES = {
    "promised",
    "refused",
    "voicemail",
    "no_answer",
    "wrong_number",
    "callback_requested",
}


def _spec() -> dict:
    return yaml.safe_load(OPENAPI_PATH.read_text(encoding="utf-8"))


def test_openapi_version_and_j9_paths() -> None:
    spec = _spec()
    assert spec["info"]["version"] == "2.8.0"
    paths = spec["paths"]
    assert "post" in paths["/v1/calls/plan-batch"]
    assert "post" in paths["/v1/calls/run-batch"]
    assert "get" in paths["/v1/calls/{runId}"]


def test_j9_paths_use_google_id_token() -> None:
    spec = _spec()
    paths = spec["paths"]
    expected = [{"GoogleIdToken": []}]
    assert paths["/v1/calls/plan-batch"]["post"]["security"] == expected
    assert paths["/v1/calls/run-batch"]["post"]["security"] == expected
    assert paths["/v1/calls/{runId}"]["get"]["security"] == expected


def test_get_kill_switch_does_not_block() -> None:
    spec = _spec()
    description = spec["paths"]["/v1/calls/{runId}"]["get"]["description"]
    assert "does **not** block" in description


def test_plan_run_get_required_fields() -> None:
    schemas = _spec()["components"]["schemas"]
    assert set(schemas["PlanBatchRequest"]["required"]) == {
        "batchId",
        "correlationId",
        "trigger",
        "dryRun",
        "locale",
        "recipients",
    }
    assert set(schemas["RunBatchRequest"]["required"]) == {
        "batchId",
        "correlationId",
        "recipients",
    }
    assert set(schemas["CallGetResponse"]["required"]) == {
        "runId",
        "status",
        "terminal",
        "phoneMasked",
        "needsHuman",
    }


def test_structured_result_integer_amount_and_outcome_enum() -> None:
    schema = _spec()["components"]["schemas"]["CallStructuredResult"]
    amount = schema["properties"]["promised_amount_minor"]
    assert amount["type"] == "integer"
    outcome = schema["properties"]["outcome"]
    assert set(outcome["enum"]) == J9_OUTCOMES


def test_proposal_tool_enum_stays_eight() -> None:
    enum = _spec()["components"]["schemas"]["ProposalTool"]["enum"]
    assert len(enum) == 8


def test_smoke_script_refuses_wait_and_frozen_hostname() -> None:
    src = SMOKE_PATH.read_text(encoding="utf-8")
    assert "create_and_wait" not in src
    assert "wait_for_result" not in src
    assert "daftar-closing-agent-1487285471" in src  # refuse needle, not a default URL
    assert 'SERVICE_URL = "https://' not in src
    assert "--allow-unauthenticated" not in src
