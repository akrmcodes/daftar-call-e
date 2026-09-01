"""Stage 1.3 observability — structured JSON logs for Cloud Run / Cloud Logging.

Cloud Run parses single-line JSON on stdout into ``jsonPayload``
(https://cloud.google.com/logging/docs/structured-logging).

Required fields (roadmap §1.3):
- session_id
- tool_name (tool events)
- latency_ms
- model_id

Also emits correlation_id from ``daftarContext`` when present (Appendix J).
Callbacks return ``None`` so agent behavior is unchanged
(https://google.github.io/adk-docs/callbacks/types-of-callbacks/).
"""

from __future__ import annotations

import json
import sys
import time
from typing import Any, Mapping, MutableMapping, Optional

# Pinned contest model — mirrored in agent.MODEL_ID; logged even when LlmRequest.model is unset.
DEFAULT_MODEL_ID = "gemini-3.5-flash"

# In-memory start timestamps (per Cloud Run instance). Keys are short-lived.
_model_starts: dict[str, float] = {}
_model_ids: dict[str, str] = {}
_tool_starts: dict[str, float] = {}


def _session_id(ctx: Any) -> str:
    """Resolve ADK session id from CallbackContext / ToolContext."""
    try:
        inv = getattr(ctx, "_invocation_context", None)
        if inv is not None:
            session = getattr(inv, "session", None)
            if session is not None and getattr(session, "id", None):
                return str(session.id)
    except Exception:
        pass
    # Fallbacks used by tests / alternate ADK shapes
    for attr in ("session_id",):
        val = getattr(ctx, attr, None)
        if val:
            return str(val)
    return ""


def _invocation_id(ctx: Any) -> str:
    try:
        return str(getattr(ctx, "invocation_id", "") or "")
    except Exception:
        return ""


def _correlation_id(ctx: Any) -> str:
    try:
        state = getattr(ctx, "state", None)
        if state is None:
            return ""
        daftar = state.get("daftarContext") if hasattr(state, "get") else None
        if isinstance(daftar, Mapping):
            cid = daftar.get("correlationId")
            if isinstance(cid, str) and cid.strip():
                return cid.strip()
    except Exception:
        pass
    return ""


def _model_from_request(llm_request: Any) -> str:
    model = getattr(llm_request, "model", None)
    if isinstance(model, str) and model.strip():
        return model.strip()
    return DEFAULT_MODEL_ID


def emit_structured(
    event: str,
    *,
    severity: str = "INFO",
    message: str = "",
    stream: Any = None,
    **fields: Any,
) -> dict[str, Any]:
    """Write one Cloud Logging structured entry to stdout (or ``stream`` for tests)."""
    entry: dict[str, Any] = {
        "severity": severity,
        "message": message or event,
        "event": event,
        "component": "closing_agent",
    }
    for key, value in fields.items():
        if value is None or value == "":
            continue
        entry[key] = value
    out = stream if stream is not None else sys.stdout
    print(json.dumps(entry, ensure_ascii=False, separators=(",", ":")), file=out, flush=True)
    return entry


def before_model_callback(
    callback_context: Any,
    llm_request: Any,
) -> None:
    """ADK: record model call start. Parameter names must match ADK exactly."""
    try:
        inv = _invocation_id(callback_context) or f"anon-{time.time_ns()}"
        _model_starts[inv] = time.perf_counter()
        model_id = _model_from_request(llm_request)
        _model_ids[inv] = model_id
        emit_structured(
            "daftar.agent.model.start",
            message=f"model_call_start model={model_id}",
            session_id=_session_id(callback_context),
            invocation_id=inv,
            model_id=model_id,
            correlation_id=_correlation_id(callback_context),
            latency_ms=0,
        )
    except Exception as exc:  # never break the agent for logging
        emit_structured(
            "daftar.agent.observability_error",
            severity="WARNING",
            message=f"before_model_callback failed: {exc}",
        )
    return None


def after_model_callback(
    callback_context: Any,
    llm_response: Any,
) -> None:
    """ADK: log model latency_ms + model_id."""
    try:
        del llm_response  # reserved for token metrics later (§1.4+)
        inv = _invocation_id(callback_context)
        started = _model_starts.pop(inv, None)
        model_id = _model_ids.pop(inv, DEFAULT_MODEL_ID)
        latency_ms = (
            int((time.perf_counter() - started) * 1000) if started is not None else -1
        )
        emit_structured(
            "daftar.agent.model",
            message=f"model_call_done latency_ms={latency_ms}",
            session_id=_session_id(callback_context),
            invocation_id=inv,
            model_id=model_id,
            correlation_id=_correlation_id(callback_context),
            latency_ms=latency_ms,
        )
    except Exception as exc:
        emit_structured(
            "daftar.agent.observability_error",
            severity="WARNING",
            message=f"after_model_callback failed: {exc}",
        )
    return None


def _tool_timer_key(tool_context: Any, tool_name: str) -> str:
    inv = _invocation_id(tool_context)
    fc = getattr(tool_context, "function_call_id", None) or tool_name
    return f"{inv}:{fc}"


def before_tool_callback(
    tool: Any,
    args: MutableMapping[str, Any] | Mapping[str, Any],
    tool_context: Any,
) -> None:
    """ADK: record tool start. Do not log full args (PII / money)."""
    try:
        del args
        name = getattr(tool, "name", None) or getattr(tool, "__name__", "unknown")
        key = _tool_timer_key(tool_context, str(name))
        _tool_starts[key] = time.perf_counter()
        emit_structured(
            "daftar.agent.tool.start",
            message=f"tool_start name={name}",
            session_id=_session_id(tool_context),
            invocation_id=_invocation_id(tool_context),
            tool_name=str(name),
            model_id=DEFAULT_MODEL_ID,
            correlation_id=_correlation_id(tool_context),
            latency_ms=0,
        )
    except Exception as exc:
        emit_structured(
            "daftar.agent.observability_error",
            severity="WARNING",
            message=f"before_tool_callback failed: {exc}",
        )
    return None


def after_tool_callback(
    tool: Any,
    args: MutableMapping[str, Any] | Mapping[str, Any],
    tool_context: Any,
    tool_response: Any,
) -> None:
    """ADK: log tool_name + latency_ms + session_id + model_id."""
    try:
        del args
        name = getattr(tool, "name", None) or getattr(tool, "__name__", "unknown")
        key = _tool_timer_key(tool_context, str(name))
        started = _tool_starts.pop(key, None)
        latency_ms = (
            int((time.perf_counter() - started) * 1000) if started is not None else -1
        )
        status = "ok"
        proposal_id = ""
        if isinstance(tool_response, Mapping):
            if tool_response.get("status") == "error":
                status = "error"
            elif "proposalId" in tool_response:
                proposal_id = str(tool_response.get("proposalId") or "")
                status = "proposal"
        emit_structured(
            "daftar.agent.tool",
            message=f"tool_done name={name} status={status} latency_ms={latency_ms}",
            session_id=_session_id(tool_context),
            invocation_id=_invocation_id(tool_context),
            tool_name=str(name),
            model_id=DEFAULT_MODEL_ID,
            correlation_id=_correlation_id(tool_context),
            latency_ms=latency_ms,
            tool_status=status,
            proposal_id=proposal_id or None,
        )
    except Exception as exc:
        emit_structured(
            "daftar.agent.observability_error",
            severity="WARNING",
            message=f"after_tool_callback failed: {exc}",
        )
    return None


def clear_timers_for_tests() -> None:
    """Test helper — reset in-memory timers."""
    _model_starts.clear()
    _model_ids.clear()
    _tool_starts.clear()
