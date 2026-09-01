"""Unit tests for Stage 1.3 structured observability logs."""

from __future__ import annotations

import io
import json
import time
import uuid
from types import SimpleNamespace
from typing import Any

from closing_agent.observability import (
    DEFAULT_MODEL_ID,
    after_model_callback,
    after_tool_callback,
    before_model_callback,
    before_tool_callback,
    clear_timers_for_tests,
    emit_structured,
)


class _FakeSession:
    def __init__(self, session_id: str, state: dict[str, Any]) -> None:
        self.id = session_id
        self.state = state


class _FakeInv:
    def __init__(self, session_id: str, state: dict[str, Any], invocation_id: str) -> None:
        self.session = _FakeSession(session_id, state)
        self.invocation_id = invocation_id
        self.agent = SimpleNamespace(name="closing_agent")


class FakeCallbackContext:
    def __init__(
        self,
        *,
        session_id: str,
        invocation_id: str,
        correlation_id: str | None = None,
    ) -> None:
        state: dict[str, Any] = {}
        if correlation_id:
            state["daftarContext"] = {"correlationId": correlation_id}
        self._invocation_context = _FakeInv(session_id, state, invocation_id)
        self.state = state
        self.invocation_id = invocation_id
        self.function_call_id = "fc-1"


def test_emit_structured_json_line() -> None:
    buf = io.StringIO()
    entry = emit_structured(
        "daftar.agent.tool",
        stream=buf,
        session_id="s1",
        tool_name="propose_debt",
        latency_ms=12,
        model_id=DEFAULT_MODEL_ID,
    )
    line = buf.getvalue().strip()
    parsed = json.loads(line)
    assert parsed["event"] == "daftar.agent.tool"
    assert parsed["session_id"] == "s1"
    assert parsed["tool_name"] == "propose_debt"
    assert parsed["latency_ms"] == 12
    assert parsed["model_id"] == "gemini-3.5-flash"
    assert entry["severity"] == "INFO"


def test_model_callbacks_emit_latency_and_model_id(monkeypatch: Any) -> None:
    clear_timers_for_tests()
    buf = io.StringIO()
    monkeypatch.setattr(
        "closing_agent.observability.sys.stdout",
        buf,
    )
    ctx = FakeCallbackContext(
        session_id="sess-model",
        invocation_id="inv-1",
        correlation_id=str(uuid.uuid4()),
    )
    req = SimpleNamespace(model="gemini-3.5-flash")
    before_model_callback(ctx, req)
    time.sleep(0.01)
    after_model_callback(ctx, SimpleNamespace())
    lines = [json.loads(x) for x in buf.getvalue().strip().splitlines()]
    assert lines[0]["event"] == "daftar.agent.model.start"
    assert lines[0]["session_id"] == "sess-model"
    assert lines[0]["model_id"] == "gemini-3.5-flash"
    done = lines[1]
    assert done["event"] == "daftar.agent.model"
    assert done["session_id"] == "sess-model"
    assert done["model_id"] == "gemini-3.5-flash"
    assert done["latency_ms"] >= 0
    assert "correlation_id" in done


def test_tool_callbacks_emit_required_fields(monkeypatch: Any) -> None:
    clear_timers_for_tests()
    buf = io.StringIO()
    monkeypatch.setattr("closing_agent.observability.sys.stdout", buf)
    ctx = FakeCallbackContext(session_id="sess-tool", invocation_id="inv-2")
    tool = SimpleNamespace(name="propose_debt")
    before_tool_callback(tool, {"contact_hint": "Mohamed"}, ctx)
    time.sleep(0.005)
    after_tool_callback(
        tool,
        {},
        ctx,
        {
            "proposalId": str(uuid.uuid4()),
            "tool": "propose_debt",
            "payload": {},
            "confirmRequired": True,
        },
    )
    lines = [json.loads(x) for x in buf.getvalue().strip().splitlines()]
    done = lines[-1]
    assert done["event"] == "daftar.agent.tool"
    assert done["session_id"] == "sess-tool"
    assert done["tool_name"] == "propose_debt"
    assert done["model_id"] == "gemini-3.5-flash"
    assert done["latency_ms"] >= 0
    assert done["tool_status"] == "proposal"
