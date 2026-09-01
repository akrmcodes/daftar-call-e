"""Daftar Closing Agent — ADK package.

Emits Appendix J proposal envelopes (see ``agent/openapi.yaml``). Never writes
to Drift; device confirm gate commits after user approval.

ADK loads ``closing_agent.agent.root_agent``. Keep this ``__init__`` free of
``google.adk`` imports so unit tests can import ``proposal`` / ``tools`` alone.
"""

__all__ = ["agent", "proposal", "tools"]
