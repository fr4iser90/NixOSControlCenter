"""Agent runner for autonomous goal-driven tasks."""

from __future__ import annotations

import json
import threading
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Iterator

from .audit import append_audit
from .config import Settings
from .jobs import get_job_store, JobEvent, JobMeta, AgentLock
from .llm import iter_chat_completion, LLMError, CancelledError
from .paths import is_disabled
from .presence import is_paused, get_presence
from .profiles import Profile, resolve_profile, is_tool_allowed, requires_confirmation, ProfileContext


def _now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


@dataclass
class AgentSettings:
    """Settings for an agent run."""
    goal: str
    max_steps: int = 50
    allow_write: bool | None = None
    allow_rebuild: bool | None = None
    allow_shell: bool | None = None
    dry_run: bool = False
    profile: str | None = None
    playbook: str | None = None
    confirm_mode: str = "writes"  # writes | always | never


Event = dict[str, Any]


class AgentRunner:
    """
    Autonomous agent runner for goal-driven tasks.
    Uses a ChatSession-like loop with job tracking.
    """

    def __init__(
        self,
        settings: Settings,
        agent_settings: AgentSettings,
        *,
        cancel_event: threading.Event | None = None,
    ) -> None:
        self.settings = settings
        self.agent_settings = agent_settings
        self.cancel_event = cancel_event or threading.Event()
        self._job: JobMeta | None = None
        self._store = get_job_store()
        self._messages: list[dict[str, Any]] = []
        self._step = 0
        self._finished = False

        self._profile = resolve_profile(
            agent_settings.profile,
            allow_write_override=agent_settings.allow_write,
            allow_rebuild_override=agent_settings.allow_rebuild,
            allow_shell_override=agent_settings.allow_shell,
        )
        self._profile_ctx = ProfileContext(self._profile)

        from .runtime import ToolRuntime
        self._runtime = ToolRuntime(settings)

    def _check_preconditions(self) -> str | None:
        """Check if agent can run. Returns error message or None."""
        if is_disabled():
            return "Agent disabled by kill-switch (DISABLE file exists)"
        if is_paused():
            presence = get_presence()
            return f"Agent paused: {presence.reason or 'no reason'}"
        return None

    def _build_system_prompt(self) -> str:
        """Build system prompt for agent mode."""
        base = self.settings.load_system_prompt()

        agent_context = f"""

## Agent Mode

You are running in agent mode to accomplish a specific goal.

**Goal:** {self.agent_settings.goal}

**Constraints:**
- Maximum steps: {self.agent_settings.max_steps}
- Profile: {self._profile.name}
- Writes allowed: {self._profile.allow_write}
- Rebuild allowed: {self._profile.allow_rebuild}
- Shell allowed: {self._profile.allow_shell}
- Dry run: {self.agent_settings.dry_run}

**Instructions:**
1. Work systematically toward the goal
2. Use tools to gather information before making changes
3. When the goal is achieved or cannot be completed, call agent_finish with a summary
4. If you encounter an error, try to recover or report the issue via agent_finish

"""
        from .memory import for_prompt
        memory_context = for_prompt(limit=10, max_chars=2000)
        if memory_context:
            agent_context += f"\n{memory_context}\n"

        return base + agent_context

    def _log_event(self, event: JobEvent) -> None:
        """Log event to job store."""
        if self._job:
            self._store.append_event(self._job.id, event)

    def run(self) -> Iterator[Event]:
        """Run the agent and yield events."""
        error = self._check_preconditions()
        if error:
            yield {"kind": "error", "text": error}
            return

        lock = AgentLock()
        if not lock.acquire(blocking=False):
            yield {"kind": "error", "text": "Another agent is already running"}
            return

        try:
            yield from self._run_with_lock()
        finally:
            lock.release()

    def _run_with_lock(self) -> Iterator[Event]:
        """Run agent with lock held."""
        self._job = self._store.create(
            self.agent_settings.goal,
            profile=self.agent_settings.profile,
            dry_run=self.agent_settings.dry_run,
            playbook=self.agent_settings.playbook,
        )
        self._store.start(self._job.id)

        yield {"kind": "job_started", "job_id": self._job.id}

        append_audit(
            "agent_started",
            actor="agent",
            job_id=self._job.id,
            detail=f"Goal: {self.agent_settings.goal}",
        )

        self._messages = [
            {"role": "system", "content": self._build_system_prompt()},
            {"role": "user", "content": f"Please accomplish this goal: {self.agent_settings.goal}"},
        ]

        tools = self._get_tools()

        try:
            while self._step < self.agent_settings.max_steps and not self._finished:
                if self.cancel_event.is_set():
                    raise CancelledError("Agent cancelled")

                error = self._check_preconditions()
                if error:
                    yield {"kind": "error", "text": error}
                    break

                self._step += 1
                self._store.increment_steps(self._job.id)
                self._log_event(JobEvent(kind="step", data={"step": self._step}))

                yield {"kind": "step", "step": self._step, "max_steps": self.agent_settings.max_steps}

                yield from self._run_step(tools)

            if not self._finished:
                yield {
                    "kind": "budget_exhausted",
                    "text": f"Max steps reached ({self.agent_settings.max_steps})",
                    "max_steps": self.agent_settings.max_steps,
                }
                yield {"kind": "status", "text": "Max steps reached"}

            self._store.finalize(
                self._job.id,
                success=self._finished,
                summary="Agent completed" if self._finished else "Max steps reached",
            )
            yield {"kind": "job_finished", "job_id": self._job.id, "success": self._finished}

        except CancelledError:
            self._store.cancel(self._job.id)
            yield {"kind": "job_cancelled", "job_id": self._job.id}
            append_audit("agent_cancelled", actor="user", job_id=self._job.id)

        except LLMError as exc:
            self._store.finalize(self._job.id, success=False, error=str(exc))
            yield {"kind": "error", "text": str(exc)}
            yield {"kind": "job_failed", "job_id": self._job.id, "error": str(exc)}
            append_audit("agent_failed", actor="agent", job_id=self._job.id, detail=str(exc))

        except Exception as exc:
            self._store.finalize(self._job.id, success=False, error=str(exc))
            yield {"kind": "error", "text": f"Unexpected error: {exc}"}
            yield {"kind": "job_failed", "job_id": self._job.id, "error": str(exc)}
            append_audit("agent_error", actor="agent", job_id=self._job.id, detail=str(exc))

    def _get_tools(self) -> list[dict[str, Any]]:
        """Get tools available for this agent run."""
        from .registry import get_registry
        registry = get_registry()

        agent_finish_tool = {
            "type": "function",
            "function": {
                "name": "agent_finish",
                "description": "Signal that the agent has completed its goal or cannot proceed. Call this when done.",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "summary": {
                            "type": "string",
                            "description": "Summary of what was accomplished or why the agent stopped",
                        },
                        "success": {
                            "type": "boolean",
                            "description": "Whether the goal was achieved",
                        },
                    },
                    "required": ["summary", "success"],
                },
            },
        }

        tools = registry.openai_tools()
        tools.append(agent_finish_tool)

        return tools

    def _run_step(self, tools: list[dict[str, Any]]) -> Iterator[Event]:
        """Run a single agent step."""
        yield {"kind": "status", "text": "Thinking...", "phase": "llm"}

        content = ""
        tool_calls: list[dict[str, Any]] = []

        for ev in iter_chat_completion(
            self.settings,
            self._messages,
            tools,
            cancel_event=self.cancel_event,
        ):
            if ev.get("type") == "delta":
                piece = ev.get("text") or ""
                content += piece
                yield {"kind": "assistant_delta", "text": piece}
            elif ev.get("type") == "done":
                msg = ev.get("message") or {}
                content = msg.get("content") or content
                tool_calls = msg.get("tool_calls") or []

        assistant_msg: dict[str, Any] = {"role": "assistant", "content": content}
        if tool_calls:
            assistant_msg["tool_calls"] = tool_calls
        self._messages.append(assistant_msg)

        if content:
            yield {"kind": "assistant", "text": content}
            self._log_event(JobEvent(kind="assistant", data={"text": content[:1000]}))

        if not tool_calls:
            self._finished = True
            return

        for tc in tool_calls:
            if self.cancel_event.is_set():
                raise CancelledError("Agent cancelled")

            fn = tc.get("function") or {}
            name = fn.get("name") or ""
            raw_args = fn.get("arguments") or "{}"

            try:
                args = json.loads(raw_args) if isinstance(raw_args, str) else raw_args
            except json.JSONDecodeError:
                args = {}

            if name == "agent_finish":
                self._finished = True
                summary = args.get("summary", "")
                success = args.get("success", True)
                yield {"kind": "agent_finish", "summary": summary, "success": success}
                self._log_event(JobEvent(kind="agent_finish", data={"summary": summary, "success": success}))
                self._store.finalize(self._job.id, success=success, summary=summary)
                self._messages.append({
                    "role": "tool",
                    "tool_call_id": tc.get("id") or name,
                    "name": name,
                    "content": json.dumps({"ok": True, "message": "Agent finished"}),
                })
                return

            yield {"kind": "tool", "name": name, "args": args}
            self._log_event(JobEvent(kind="tool", data={"name": name, "args": args}))

            result = self._call_tool(name, args)

            payload = json.dumps(result, ensure_ascii=False, indent=2)
            if len(payload) > 6000:
                payload = payload[:6000] + "\n... (truncated)"

            yield {"kind": "tool_result", "name": name, "text": payload}
            self._log_event(JobEvent(kind="tool_result", data={"name": name, "content": payload[:1000]}))

            self._messages.append({
                "role": "tool",
                "tool_call_id": tc.get("id") or name,
                "name": name,
                "content": payload,
            })

            append_audit(
                "tool_call",
                actor="agent",
                job_id=self._job.id if self._job else None,
                tool=name,
                args=args,
                result="ok" if result.get("ok") else "error",
            )

    def _call_tool(self, name: str, args: dict[str, Any]) -> dict[str, Any]:
        """Call a tool with profile and dry-run checks."""
        allowed, reason = self._profile_ctx.check_tool(name)
        if not allowed:
            return {"ok": False, "error": reason}

        if self.agent_settings.dry_run and name in ("apply_module_config", "apply_system"):
            return {
                "ok": False,
                "error": "Dry-run mode: write operations are simulated",
                "dry_run": True,
            }

        self._profile_ctx.record_call(name)

        return self._runtime.call(name, args)

    def cancel(self) -> None:
        """Request cancellation of the agent."""
        self.cancel_event.set()


def run_agent(
    goal: str,
    settings: Settings | None = None,
    *,
    max_steps: int = 50,
    dry_run: bool = False,
    profile: str | None = None,
    playbook: str | None = None,
) -> Iterator[Event]:
    """Convenience function to run an agent."""
    if settings is None:
        settings = Settings.from_env()

    agent_settings = AgentSettings(
        goal=goal,
        max_steps=max_steps,
        dry_run=dry_run,
        profile=profile,
        playbook=playbook,
    )

    runner = AgentRunner(settings, agent_settings)
    yield from runner.run()
