"""Shared chat session used by CLI and GUI."""

from __future__ import annotations

import json
import threading
from dataclasses import dataclass, field, replace
from typing import Any, Callable, Iterator

from .auth import (
    ensure_auth,
    prompt_and_store_auth,
    refresh_auth_on_unauthorized,
    with_cached_credentials,
)
from .config import Settings
from .history import (
    new_session_id,
    save_session,
    strip_heavy_content,
    title_from_messages,
)
from .llm import (
    CancelledError,
    LLMError,
    iter_chat_completion,
    list_models,
    model_supports_vision,
    resolve_model,
)
from .runtime import ToolRuntime

Event = dict[str, Any]
PromptAuthFn = Callable[[Settings], Settings]
ConfirmHook = Callable[[dict[str, Any]], bool]


@dataclass
class ChatSession:
    settings: Settings
    runtime: ToolRuntime
    messages: list[dict[str, Any]] = field(default_factory=list)
    model_label: str = "auto"
    max_rounds: int = 8
    session_id: str = field(default_factory=new_session_id)
    title: str = "New chat"
    cancel_event: threading.Event = field(default_factory=threading.Event)
    available_models: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self) -> None:
        if not self.messages:
            self.messages = [
                {
                    "role": "system",
                    "content": self.settings.load_system_prompt(),
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
    ) -> "ChatSession":
        settings = settings or Settings.from_env(client_mode="chat")
        settings = with_cached_credentials(settings)

        if prompt_auth is not None:
            from .auth import probe_needs_auth

            if not settings.api_key:
                need = probe_needs_auth(settings)
                if need is True or settings.api == "anthropic":
                    settings = prompt_auth(settings)
        elif interactive_auth:
            settings = ensure_auth(settings, interactive=True)

        runtime = ToolRuntime(settings, confirm_hook=confirm_hook)
        session = cls(settings=settings, runtime=runtime)
        if messages is not None:
            session.messages = messages
        if session_id:
            session.session_id = session_id
        if title:
            session.title = title
        session.refresh_models()
        session.refresh_model_label()
        return session

    def set_confirm_hook(self, hook: ConfirmHook | None) -> None:
        self.runtime.confirm_hook = hook

    def request_cancel(self) -> None:
        self.cancel_event.set()

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
        try:
            self.model_label = resolve_model(self.settings)
        except LLMError:
            self.model_label = "auto (unavailable)"
        return self.model_label

    def set_model(self, model_id: str | None) -> None:
        self.settings = replace(self.settings, model=model_id or None)
        self.runtime = ToolRuntime(
            self.settings, confirm_hook=self.runtime.confirm_hook
        )
        self.refresh_model_label()

    def current_model_vision(self) -> bool:
        mid = self.settings.model or self.model_label
        for m in self.available_models:
            if m.get("id") == mid:
                return bool(m.get("vision"))
        return model_supports_vision(mid)

    def persist(self) -> None:
        self.title = title_from_messages(self.messages) or self.title
        save_session(
            {
                "id": self.session_id,
                "title": self.title,
                "model": self.settings.model or self.model_label,
                "endpoint": self.settings.endpoint,
                "messages": strip_heavy_content(self.messages),
            }
        )

    def reset_conversation(self) -> None:
        self.session_id = new_session_id()
        self.title = "New chat"
        self.messages = [
            {
                "role": "system",
                "content": self.settings.load_system_prompt(),
            }
        ]
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
        for _ in range(self.max_rounds):
            if self.cancel_event.is_set():
                raise CancelledError("cancelled")

            yield {
                "kind": "status",
                "text": f"Waiting for {self.model_label}",
                "phase": "llm",
            }
            yield {"kind": "assistant_start"}

            content = ""
            tool_calls: list[dict[str, Any]] = []
            for ev in iter_chat_completion(
                self.settings,
                self.messages,
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
                    if msg.get("model"):
                        self.model_label = str(msg["model"])

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
                return

            if content:
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
                yield {
                    "kind": "status",
                    "text": f"Running tool: {name}",
                    "phase": "tool",
                }
                result = self.runtime.call(name, args)
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

        yield {
            "kind": "assistant",
            "text": "(stopped after max tool rounds)",
        }


def terminal_prompt_auth(settings: Settings) -> Settings:
    return prompt_and_store_auth(settings)
