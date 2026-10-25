"""Shared chat session used by CLI and GUI."""

from __future__ import annotations

import json
import threading
import time
import uuid
from dataclasses import dataclass, field, replace
from typing import Any, Callable, Iterator

from core.policy.auth import (
    ensure_auth,
    prompt_and_store_auth,
    refresh_auth_on_unauthorized,
    with_cached_credentials,
)
from core.store.config import Settings, UNLIMITED, is_unlimited
from core.runtime.context import KEEP_RECENT_MESSAGES, ContextMeter, compact_stream
from core.runtime.history import (
    new_session_id,
    save_session,
    strip_heavy_content,
    title_from_messages,
)
from core.runtime.llm import (
    CancelledError,
    LLMError,
    is_context_length_error,
    iter_chat_completion,
    list_models,
    model_supports_vision,
)
from core.runtime.runtime import ToolRuntime, ask_payload

Event = dict[str, Any]
PromptAuthFn = Callable[[Settings], Settings]
ConfirmHook = Callable[[dict[str, Any]], bool]
AskHook = Callable[[dict[str, Any]], str | None]
ASK_TIMEOUT_SEC = 600.0


@dataclass
class ChatSession:
    settings: Settings
    runtime: ToolRuntime
    messages: list[dict[str, Any]] = field(default_factory=list)
    model_label: str = "auto"
    max_rounds: int = UNLIMITED
    session_id: str = field(default_factory=new_session_id)
    title: str = "New chat"
    cancel_event: threading.Event = field(default_factory=threading.Event)
    available_models: list[dict[str, Any]] = field(default_factory=list)
    meter: ContextMeter | None = None
    # Compaction deletes the message a title came from, so a real title is latched
    # once instead of being re-derived from whatever survived compaction.
    title_locked: bool = False
    # ask_id → pending `ask_user`. The worker blocks in `_wait_ask`; whichever
    # surface rendered the question releases it through `answer_ask`.
    _asks: dict[str, dict[str, Any]] = field(
        default_factory=dict, init=False, repr=False
    )
    _ask_lock: threading.Lock = field(default_factory=threading.Lock, init=False, repr=False)

    def ctx_meter(self) -> ContextMeter:
        """Token meter; built on first use because detecting the window is HTTP."""
        if self.meter is None:
            self.meter = ContextMeter.for_settings(self.settings)
        return self.meter

    def context_report(self) -> dict[str, Any]:
        return self.ctx_meter().report(self.messages)

    def drop_context_meter(self) -> None:
        """Settings changed (provider swap) — the old window/anchor no longer applies."""
        self.meter = None

    def _context_event(self) -> Event:
        return {"kind": "context", **self.context_report()}

    def compact_now(self, keep: int | None = None) -> Iterator[Event]:
        """Manual compaction (`/compact`) — same code path as the automatic one."""
        yield from compact_stream(
            self.settings,
            self.messages,
            self.ctx_meter(),
            KEEP_RECENT_MESSAGES if keep is None else max(2, int(keep)),
        )
        self.persist()

    def _system_prompt(self) -> str:
        from core.runtime.registry import tools_prompt_section

        return self.settings.load_system_prompt() + tools_prompt_section(
            allow_write=self.settings.writes_enabled,
            allow_rebuild=bool(self.settings.allow_rebuild),
        )

    def refresh_system_prompt(self) -> None:
        """Replace/insert system message with current tool catalog (role-filtered)."""
        prompt = self._system_prompt()
        if self.messages and self.messages[0].get("role") == "system":
            self.messages[0] = {"role": "system", "content": prompt}
        else:
            self.messages.insert(0, {"role": "system", "content": prompt})

    def __post_init__(self) -> None:
        self._install_ask_hook()
        if not self.messages:
            self.messages = [
                {
                    "role": "system",
                    "content": self._system_prompt(),
                }
            ]

    @classmethod
    def create(
        cls,
        settings: Settings | None = None,
        *,
        interactive_auth: bool = True,
        prompt_auth: PromptAuthFn | None = None,
        confirm_hook: ConfirmHook | None = None,
        messages: list[dict[str, Any]] | None = None,
        session_id: str | None = None,
        title: str | None = None,
        refresh_models: bool = True,
        available_models: list[dict[str, Any]] | None = None,
        max_rounds: int | None = None,
    ) -> "ChatSession":
        settings = settings or Settings.from_env(client_mode="chat")
        settings = with_cached_credentials(settings)

        if prompt_auth is not None:
            from core.policy.auth import probe_needs_auth

            if not settings.api_key:
                need = probe_needs_auth(settings)
                if need is True or settings.api == "anthropic":
                    settings = prompt_auth(settings)
        elif interactive_auth:
            settings = ensure_auth(settings, interactive=True)

        runtime = ToolRuntime(settings, confirm_hook=confirm_hook)
        session = cls(
            settings=settings,
            runtime=runtime,
            max_rounds=(
                settings.chat_max_rounds if max_rounds is None else int(max_rounds)
            ),
        )
        if messages is not None:
            session.messages = messages
            session.refresh_system_prompt()
        if session_id:
            session.session_id = session_id
        if title:
            session.title = title
            session.title_locked = True
        if refresh_models:
            # HTTP GET /models — avoid on chat-switch (pass refresh_models=False).
            session.refresh_models()
        elif available_models is not None:
            session.available_models = list(available_models)
        session.refresh_model_label()
        return session

    def set_confirm_hook(self, hook: ConfirmHook | None) -> None:
        self.runtime.confirm_hook = hook

    def attach_runtime(self, runtime: ToolRuntime) -> None:
        """Swap the runtime (new credentials, new provider) and keep `ask_user` alive.

        Surfaces that rebuild the runtime would otherwise leave the next question
        with no hook, and the model would get "No interactive surface" mid-chat.
        """
        self.runtime = runtime
        self._install_ask_hook()

    def _install_ask_hook(self) -> None:
        """`ask_user` waits on this session, not on a desktop notification."""
        self.runtime.ask_hook = self._wait_ask

    def _begin_ask(self, name: str, tool_call_id: Any, args: dict[str, Any]) -> Event | None:
        """Register a pending question and return what to report to the surface.

        Must run *before* the tool call: the hook that waits for the answer runs
        inside this generator, so a surface could never report the question after.
        """
        if str(name or "") != "ask_user":
            return None
        payload = ask_payload(tool_call_id, args)
        if not payload["question"]:
            return None  # the tool answers with its own error
        if not payload["ask_id"]:
            # Some gateways drop tool_call ids; the surface still needs one to answer into.
            payload["ask_id"] = f"ask-{uuid.uuid4().hex[:8]}"
        self.abandon_asks()  # a second live question means the first was orphaned
        with self._ask_lock:
            self._asks[payload["ask_id"]] = {
                "settled": threading.Event(),
                "answer": None,
                "cancelled": False,
            }
        return payload

    def _wait_ask(self, payload: dict[str, Any]) -> str | None:
        """The hook `ToolRuntime` calls: wait for an answer, a cancel, or the deadline.

        Polls the settle flag instead of blocking on it so a cancel (which only
        sets `cancel_event`) frees the worker without a second signal path.
        """
        ask_id = str(payload.get("ask_id") or "")
        with self._ask_lock:
            entry = self._asks.get(ask_id)
        if entry is None:
            return None
        deadline = time.monotonic() + ASK_TIMEOUT_SEC
        while not entry["settled"].wait(timeout=0.25):
            if self.cancel_event.is_set() or time.monotonic() >= deadline:
                with self._ask_lock:
                    entry["cancelled"] = True
                    entry["settled"].set()
                break
        with self._ask_lock:
            self._asks.pop(ask_id, None)
            answer = None if entry.get("cancelled") else entry.get("answer")
        return None if answer is None else str(answer)

    def answer_ask(self, ask_id: str, text: str | None) -> bool:
        """Give the waiting tool the human's answer (``None``/empty = skipped)."""
        with self._ask_lock:
            entry = self._asks.get(str(ask_id or ""))
            if entry is None:
                return False
            entry["answer"] = text
            entry["settled"].set()
        return True

    def abandon_asks(self) -> None:
        """Free every pending question (cancelled run, chat closed under it)."""
        with self._ask_lock:
            for entry in self._asks.values():
                entry["cancelled"] = True
                entry["settled"].set()
            self._asks.clear()

    def pending_ask_ids(self) -> list[str]:
        with self._ask_lock:
            return list(self._asks)

    def request_cancel(self) -> None:
        self.cancel_event.set()
        self.abandon_asks()

    def clear_cancel(self) -> None:
        self.cancel_event.clear()

    def refresh_models(self) -> list[dict[str, Any]]:
        try:
            self.available_models = list_models(self.settings)
        except LLMError:
            self.available_models = []
            if self.settings.model:
                self.available_models = [
                    {
                        "id": self.settings.model,
                        "vision": model_supports_vision(self.settings.model),
                    }
                ]
        return self.available_models

    def refresh_model_label(self) -> str:
        if self.settings.model:
            self.model_label = self.settings.model
            return self.model_label
        if self.settings.api != "openai-compatible":
            self.model_label = self.settings.model or "unset"
            return self.model_label
        # Do not hit the network here (GUI open path). Resolve on first send.
        self.model_label = "auto"
        return self.model_label

    def set_model(self, model_id: str | None) -> None:
        self.settings = replace(self.settings, model=model_id or None)
        self.runtime = ToolRuntime(
            self.settings, confirm_hook=self.runtime.confirm_hook
        )
        self._install_ask_hook()
        # Window size is per model — the probe is keyed on endpoint|model.
        self.meter = None
        self.refresh_model_label()

    def current_model_vision(self) -> bool:
        mid = self.settings.model or self.model_label
        for m in self.available_models:
            if m.get("id") == mid:
                return bool(m.get("vision"))
        return model_supports_vision(mid)

    def persist(self) -> None:
        if not self.title_locked:
            derived = title_from_messages(self.messages)
            if derived and derived != "New chat":
                self.title = derived
                self.title_locked = True
        provider_name = ""
        try:
            from core.store.providers import find_provider_by_endpoint

            p = find_provider_by_endpoint(self.settings.endpoint)
            if p:
                provider_name = p.name
        except Exception:
            pass
        save_session(
            {
                "id": self.session_id,
                "title": self.title,
                "model": self.settings.model or self.model_label,
                "endpoint": self.settings.endpoint,
                "api": self.settings.api,
                "provider": provider_name,
                "messages": strip_heavy_content(self.messages),
            }
        )

    def reset_conversation(self) -> None:
        self.abandon_asks()
        self.session_id = new_session_id()
        self.title = "New chat"
        self.title_locked = False
        self.messages = [
            {
                "role": "system",
                "content": self._system_prompt(),
            }
        ]
        if self.meter is not None:
            self.meter.reset_anchor()
            self.meter.compactions = 0
        self.persist()

    def send(
        self,
        user_text: str,
        *,
        images: list[dict[str, str]] | None = None,
        prompt_auth: PromptAuthFn | None = None,
    ) -> Iterator[Event]:
        text = (user_text or "").strip()
        images = images or []
        if not text and not images:
            return

        self.clear_cancel()

        content: Any
        if images:
            parts: list[dict[str, Any]] = []
            if text:
                parts.append({"type": "text", "text": text})
            for img in images:
                mime = img.get("mime") or "image/png"
                b64 = img.get("data_b64") or ""
                if not b64:
                    continue
                parts.append(
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime};base64,{b64}"},
                    }
                )
            content = parts
            preview = text or "(image)"
            if images and text:
                preview = f"{text}  [{len(images)} image(s)]"
            elif images:
                preview = f"[{len(images)} image(s)]"
            yield {"kind": "user", "text": preview, "images": len(images)}
        else:
            content = text
            yield {"kind": "user", "text": text}

        self.refresh_system_prompt()
        self.messages.append({"role": "user", "content": content})
        tools = self.runtime.openai_tools()

        try:
            yield from self._run_turn(tools)
            self.persist()
        except CancelledError:
            yield {"kind": "status", "text": "Cancelled", "phase": "cancel"}
            yield {"kind": "error", "text": "Generation cancelled."}
            self.persist()
        except LLMError as exc:
            if is_context_length_error(exc):
                # The estimate under-shot, or the gateway's window is smaller
                # than advertised. Compact for real and give the turn one more
                # chance instead of surfacing a raw 400.
                yield {
                    "kind": "status",
                    "text": "Context limit hit — compacting and retrying once…",
                    "phase": "compact",
                }
                yield from compact_stream(
                    self.settings, self.messages, self.ctx_meter()
                )
                try:
                    yield from self._run_turn(tools)
                except (CancelledError, LLMError) as retry_exc:
                    # No messages.pop() here: compaction rewrote the history, so a
                    # blind pop could delete the summary instead of the prompt.
                    yield {"kind": "error", "text": str(retry_exc)}
                else:
                    self.persist()
                yield {"kind": "done"}
                return
            refreshed = None
            if prompt_auth is not None:
                low = str(exc).lower()
                if "401" in low or "403" in low or "unauthorized" in low:
                    refreshed = prompt_auth(self.settings)
            else:
                refreshed = refresh_auth_on_unauthorized(
                    self.settings, exc, interactive=True
                )
            if refreshed is not None:
                self.settings = refreshed
                self.runtime = ToolRuntime(
                    self.settings, confirm_hook=self.runtime.confirm_hook
                )
                self._install_ask_hook()
                self.refresh_model_label()
                yield {"kind": "status", "text": "Auth updated — retrying…"}
                try:
                    yield from self._run_turn(tools)
                    self.persist()
                    yield {"kind": "done"}
                    return
                except CancelledError:
                    yield {"kind": "error", "text": "Generation cancelled."}
                    yield {"kind": "done"}
                    return
                except LLMError as exc2:
                    self.messages.pop()
                    yield {"kind": "error", "text": str(exc2)}
                    yield {"kind": "done"}
                    return
            self.messages.pop()
            yield {"kind": "error", "text": str(exc)}
        except Exception as exc:  # noqa: BLE001
            yield {"kind": "error", "text": str(exc)}

        yield {"kind": "done"}

    def _run_turn(self, tools: list[dict[str, Any]]) -> Iterator[Event]:
        rounds = 0
        meter = self.ctx_meter()
        meter.note_tools(tools)
        while is_unlimited(self.max_rounds) or rounds < self.max_rounds:
            rounds += 1
            if self.cancel_event.is_set():
                raise CancelledError("cancelled")

            # Compact before the request that would cross the threshold, not
            # after the gateway rejects it — a rejected prompt costs the round.
            if self.settings.auto_compact and meter.over_threshold(self.messages):
                yield from compact_stream(self.settings, self.messages, meter)

            yield {
                "kind": "status",
                "text": f"Waiting for {self.model_label}",
                "phase": "llm",
            }
            yield {"kind": "assistant_start"}

            content = ""
            tool_calls: list[dict[str, Any]] = []
            usage: dict[str, Any] = {}
            sent = len(self.messages)
            for ev in iter_chat_completion(
                self.settings,
                self.messages,
                tools,
                cancel_event=self.cancel_event,
            ):
                if ev.get("type") == "thinking_delta":
                    yield {
                        "kind": "thinking_delta",
                        "text": str(ev.get("text") or ""),
                    }
                elif ev.get("type") == "delta":
                    piece = ev.get("text") or ""
                    content += piece
                    yield {"kind": "assistant_delta", "text": piece}
                elif ev.get("type") == "done":
                    msg = ev.get("message") or {}
                    content = msg.get("content") or content
                    tool_calls = msg.get("tool_calls") or []
                    usage = msg.get("usage") or usage
                    if msg.get("model"):
                        self.model_label = str(msg["model"])
            meter.observe(sent, usage)

            assistant_msg: dict[str, Any] = {
                "role": "assistant",
                "content": content,
            }
            if tool_calls:
                assistant_msg["tool_calls"] = tool_calls
            self.messages.append(assistant_msg)

            if not tool_calls:
                yield {
                    "kind": "assistant",
                    "text": content or "(empty response)",
                    "streamed": True,
                }
                yield self._context_event()
                return

            # Tool-only rounds often have empty/whitespace content — do not emit
            # a second empty assistant bubble before the tool traces.
            if content.strip():
                yield {
                    "kind": "assistant",
                    "text": content,
                    "streamed": True,
                }

            for tc in tool_calls:
                if self.cancel_event.is_set():
                    raise CancelledError("cancelled")
                fn = tc.get("function") or {}
                name = fn.get("name") or ""
                raw_args = fn.get("arguments") or "{}"
                try:
                    args = (
                        json.loads(raw_args)
                        if isinstance(raw_args, str)
                        else raw_args
                    )
                except json.JSONDecodeError:
                    args = {}
                yield {"kind": "tool", "name": name, "args": args}
                ask = self._begin_ask(name, tc.get("id"), args)
                if ask is not None:
                    yield {"kind": "ask", **ask}
                yield {
                    "kind": "status",
                    "text": f"Running tool: {name}",
                    "phase": "tool",
                }
                result = self.runtime.call(
                    name, args, ask_id=(ask or {}).get("ask_id") or tc.get("id")
                )
                payload = json.dumps(result, ensure_ascii=False, indent=2)
                if len(payload) > 6000:
                    payload = payload[:6000] + "\n... (truncated)"
                yield {
                    "kind": "tool_result",
                    "name": name,
                    "text": payload,
                }
                self.messages.append(
                    {
                        "role": "tool",
                        "tool_call_id": tc.get("id") or name,
                        "name": name,
                        "content": payload,
                    }
                )

            yield self._context_event()

        # Only reachable with an explicit budget: surfaces drop event kinds they do
        # not know, so this stays an assistant bubble rather than a new kind.
        yield {
            "kind": "assistant",
            "text": f"(stopped after {self.max_rounds} tool rounds)",
        }


def terminal_prompt_auth(settings: Settings) -> Settings:
    return prompt_and_store_auth(settings)
