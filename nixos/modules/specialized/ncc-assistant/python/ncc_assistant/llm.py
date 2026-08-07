"""LLM clients for the built-in chat loop (OpenAI-compatible + Anthropic)."""

from __future__ import annotations

import json
import threading
from typing import Any, Iterator

import httpx

from .config import Settings


class LLMError(RuntimeError):
    pass


class CancelledError(LLMError):
    pass


def _auth_headers(settings: Settings) -> dict[str, str]:
    if not settings.api_key:
        return {}
    name = (settings.api_header_name or "").strip()
    if not name or name.lower() == "authorization":
        return {"Authorization": f"Bearer {settings.api_key}"}
    return {name: settings.api_key}


def list_models(settings: Settings) -> list[dict[str, Any]]:
    """Return model dicts from GET {endpoint}/models (id + raw metadata)."""
    if settings.api == "anthropic":
        mid = settings.model or "claude-sonnet-4-20250514"
        return [{"id": mid, "owned_by": "anthropic", "vision": False}]

    url = f"{settings.endpoint}/models"
    try:
        with httpx.Client(timeout=30.0) as client:
            resp = client.get(url, headers=_auth_headers(settings))
            if resp.status_code >= 400:
                raise LLMError(
                    f"GET {url} → HTTP {resp.status_code}: {resp.text[:400]}"
                )
            data = resp.json()
    except LLMError:
        raise
    except httpx.HTTPError as exc:
        raise LLMError(f"GET {url} failed: {exc}") from exc
    models = data.get("data") or data.get("models") or []
    out: list[dict[str, Any]] = []
    for m in models:
        if isinstance(m, str):
            out.append({"id": m, "vision": model_id_looks_vision(m)})
            continue
        if not isinstance(m, dict):
            continue
        mid = m.get("id") or m.get("name")
        if not mid:
            continue
        entry = dict(m)
        entry["id"] = mid
        entry["vision"] = model_supports_vision(entry)
        out.append(entry)
    return out


def model_id_looks_vision(model_id: str) -> bool:
    low = model_id.lower()
    keys = (
        "vision",
        "vl-",
        "-vl",
        "vlm",
        "llava",
        "moondream",
        "minicpm-v",
        "qwen2-vl",
        "qwen2.5-vl",
        "qwen3-vl",
        "internvl",
        "pixtral",
        "gpt-4o",
        "gpt-4.1",
        "claude-3",
        "gemini",
        "gemma-3",
    )
    return any(k in low for k in keys)


def model_supports_vision(model: dict[str, Any] | str) -> bool:
    if isinstance(model, str):
        return model_id_looks_vision(model)
    mid = str(model.get("id") or model.get("name") or "")
    if model_id_looks_vision(mid):
        return True
    # Common OpenAI / llama.cpp / Ollama metadata shapes
    caps = model.get("capabilities") or model.get("capability") or {}
    if isinstance(caps, dict) and (
        caps.get("vision") or caps.get("multimodal") or caps.get("image")
    ):
        return True
    modalities = model.get("modalities") or model.get("input_modalities") or []
    if isinstance(modalities, list) and any(
        str(x).lower() in ("image", "vision", "multimodal") for x in modalities
    ):
        return True
    arch = str(model.get("architecture") or model.get("model_type") or "").lower()
    if "vision" in arch or "vl" in arch:
        return True
    meta = model.get("meta") or model.get("details") or {}
    if isinstance(meta, dict):
        family = str(meta.get("family") or meta.get("families") or "").lower()
        if "llava" in family or "vision" in family or "vl" in family:
            return True
    return False


def resolve_model(settings: Settings, client: httpx.Client | None = None) -> str:
    if settings.model:
        return settings.model

    url = f"{settings.endpoint}/models"
    headers = _auth_headers(settings)
    own = client is None
    http = client or httpx.Client(timeout=30.0)
    try:
        try:
            resp = http.get(url, headers=headers)
        except httpx.HTTPError as exc:
            raise LLMError(
                f"model auto-detect failed (GET {url}): {exc}. "
                "Set modules.specialized.ncc-assistant.model."
            ) from exc
        if resp.status_code >= 400:
            raise LLMError(
                f"model auto-detect failed (GET {url} → HTTP {resp.status_code}): "
                f"{resp.text[:400]}. Set modules.specialized.ncc-assistant.model."
            )
        data = resp.json()
        models = data.get("data") or data.get("models") or []
        if not models:
            raise LLMError(
                f"GET {url} returned no models. "
                "Set modules.specialized.ncc-assistant.model explicitly."
            )
        first = models[0]
        mid = first.get("id") if isinstance(first, dict) else str(first)
        if not mid:
            raise LLMError(f"GET {url}: first model has no id")
        return mid
    finally:
        if own:
            http.close()


def chat_completion(
    settings: Settings,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    if settings.api == "anthropic":
        return _anthropic(settings, messages, tools)
    return _openai_compatible(settings, messages, tools)


def iter_chat_completion(
    settings: Settings,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]] | None = None,
    cancel_event: threading.Event | None = None,
) -> Iterator[dict[str, Any]]:
    """
    Yield stream events:
      {"type":"delta","text":"..."}
      {"type":"done","message":{role,content,tool_calls,model}}
    Falls back to non-streaming if the server rejects stream=true.
    """
    if settings.api == "anthropic":
        reply = _anthropic(settings, messages, tools)
        if reply.get("content"):
            yield {"type": "delta", "text": reply["content"]}
        yield {"type": "done", "message": reply}
        return

    try:
        yield from _openai_stream(settings, messages, tools, cancel_event)
    except CancelledError:
        raise
    except LLMError as exc:
        # Some gateways reject streaming with tools — fall back once.
        if "stream" in str(exc).lower() or "400" in str(exc):
            if cancel_event and cancel_event.is_set():
                raise CancelledError("cancelled") from exc
            reply = _openai_compatible(settings, messages, tools)
            if reply.get("content"):
                yield {"type": "delta", "text": reply["content"]}
            yield {"type": "done", "message": reply}
            return
        raise


def _openai_payload(
    settings: Settings,
    model: str,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]] | None,
    *,
    stream: bool,
) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "model": model,
        "messages": messages,
        "stream": stream,
    }
    if settings.temperature is not None:
        payload["temperature"] = settings.temperature
    if settings.max_tokens is not None:
        payload["max_tokens"] = settings.max_tokens
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
    return payload


def _openai_compatible(
    settings: Settings,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]] | None,
) -> dict[str, Any]:
    url = f"{settings.endpoint}/chat/completions"
    headers = {"Content-Type": "application/json", **_auth_headers(settings)}

    with httpx.Client(timeout=120.0) as client:
        model = resolve_model(settings, client)
        payload = _openai_payload(settings, model, messages, tools, stream=False)
        resp = client.post(url, headers=headers, json=payload)
        if resp.status_code >= 400:
            raise LLMError(f"LLM HTTP {resp.status_code}: {resp.text[:800]}")
        data = resp.json()

    choice = (data.get("choices") or [{}])[0]
    message = choice.get("message") or {}
    return {
        "role": "assistant",
        "content": message.get("content") or "",
        "tool_calls": message.get("tool_calls") or [],
        "model": model,
        "raw": data,
    }


def _merge_tool_call_delta(
    acc: dict[int, dict[str, Any]], delta_calls: list[dict[str, Any]]
) -> None:
    for tc in delta_calls:
        idx = int(tc.get("index", 0))
        slot = acc.setdefault(
            idx,
            {
                "id": "",
                "type": "function",
                "function": {"name": "", "arguments": ""},
            },
        )
        if tc.get("id"):
            slot["id"] = tc["id"]
        if tc.get("type"):
            slot["type"] = tc["type"]
        fn = tc.get("function") or {}
        if fn.get("name"):
            slot["function"]["name"] += fn["name"]
        if fn.get("arguments") is not None:
            slot["function"]["arguments"] += str(fn["arguments"])


def _openai_stream(
    settings: Settings,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]] | None,
    cancel_event: threading.Event | None,
) -> Iterator[dict[str, Any]]:
    url = f"{settings.endpoint}/chat/completions"
    headers = {"Content-Type": "application/json", **_auth_headers(settings)}

    content_parts: list[str] = []
    tool_acc: dict[int, dict[str, Any]] = {}
    model_name = settings.model or ""

    with httpx.Client(timeout=httpx.Timeout(120.0, connect=30.0)) as client:
        model_name = resolve_model(settings, client)
        payload = _openai_payload(settings, model_name, messages, tools, stream=True)
        with client.stream("POST", url, headers=headers, json=payload) as resp:
            if resp.status_code >= 400:
                body = resp.read().decode("utf-8", errors="replace")
                raise LLMError(f"LLM HTTP {resp.status_code}: {body[:800]}")

            for line in resp.iter_lines():
                if cancel_event and cancel_event.is_set():
                    raise CancelledError("cancelled")
                if not line:
                    continue
                if line.startswith(":"):
                    continue
                if not line.startswith("data:"):
                    continue
                data_s = line[5:].strip()
                if data_s == "[DONE]":
                    break
                try:
                    chunk = json.loads(data_s)
                except json.JSONDecodeError:
                    continue
                if chunk.get("model"):
                    model_name = chunk["model"]
                choice = (chunk.get("choices") or [{}])[0]
                delta = choice.get("delta") or {}
                piece = delta.get("content")
                if piece:
                    content_parts.append(piece)
                    yield {"type": "delta", "text": piece}
                if delta.get("tool_calls"):
                    _merge_tool_call_delta(tool_acc, delta["tool_calls"])

    cleaned: list[dict[str, Any]] = []
    for i in sorted(tool_acc):
        tc = tool_acc[i]
        fn = tc.get("function") or {}
        cleaned.append(
            {
                "id": tc.get("id") or f"tool_{i}",
                "type": tc.get("type") or "function",
                "function": {
                    "name": fn.get("name") or "",
                    "arguments": fn.get("arguments") or "{}",
                },
            }
        )

    yield {
        "type": "done",
        "message": {
            "role": "assistant",
            "content": "".join(content_parts),
            "tool_calls": cleaned,
            "model": model_name,
        },
    }


def _anthropic(
    settings: Settings,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]] | None,
) -> dict[str, Any]:
    if not settings.api_key:
        raise LLMError("ANTHROPIC_API_KEY / NCC_ASSISTANT_API_KEY required")
    if not settings.model:
        raise LLMError(
            'api = "anthropic" requires an explicit model '
            "(e.g. claude-sonnet-4-20250514)"
        )

    system = ""
    converted: list[dict[str, Any]] = []
    for msg in messages:
        role = msg.get("role")
        if role == "system":
            system = msg.get("content") or ""
            continue
        if role == "tool":
            converted.append(
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "tool_result",
                            "tool_use_id": msg.get("tool_call_id"),
                            "content": msg.get("content") or "",
                        }
                    ],
                }
            )
            continue
        if role == "assistant" and msg.get("tool_calls"):
            content: list[dict[str, Any]] = []
            if msg.get("content"):
                content.append({"type": "text", "text": msg["content"]})
            for tc in msg["tool_calls"]:
                fn = tc.get("function") or {}
                args_raw = fn.get("arguments") or "{}"
                try:
                    args = json.loads(args_raw) if isinstance(args_raw, str) else args_raw
                except json.JSONDecodeError:
                    args = {}
                content.append(
                    {
                        "type": "tool_use",
                        "id": tc.get("id") or "tool",
                        "name": fn.get("name"),
                        "input": args,
                    }
                )
            converted.append({"role": "assistant", "content": content})
            continue
        # Multimodal user content may be a list — Anthropic needs conversion; pass text only
        c = msg.get("content")
        if isinstance(c, list):
            texts = [
                p.get("text", "")
                for p in c
                if isinstance(p, dict) and p.get("type") == "text"
            ]
            converted.append({"role": role, "content": "\n".join(texts)})
        else:
            converted.append({"role": role, "content": c or ""})

    anthropic_tools = []
    for t in tools or []:
        fn = t.get("function") or t
        anthropic_tools.append(
            {
                "name": fn["name"],
                "description": fn.get("description") or "",
                "input_schema": fn.get("parameters")
                or {"type": "object", "properties": {}},
            }
        )

    payload: dict[str, Any] = {
        "model": settings.model,
        "messages": converted,
        "max_tokens": settings.max_tokens or 4096,
    }
    if settings.temperature is not None:
        payload["temperature"] = settings.temperature
    if system:
        payload["system"] = system
    if anthropic_tools:
        payload["tools"] = anthropic_tools

    with httpx.Client(timeout=120.0) as client:
        resp = client.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "Content-Type": "application/json",
                "x-api-key": settings.api_key,
                "anthropic-version": "2023-06-01",
            },
            json=payload,
        )
        if resp.status_code >= 400:
            raise LLMError(f"Anthropic HTTP {resp.status_code}: {resp.text[:800]}")
        data = resp.json()

    text_parts: list[str] = []
    tool_calls: list[dict[str, Any]] = []
    for block in data.get("content") or []:
        if block.get("type") == "text":
            text_parts.append(block.get("text") or "")
        elif block.get("type") == "tool_use":
            tool_calls.append(
                {
                    "id": block.get("id"),
                    "type": "function",
                    "function": {
                        "name": block.get("name"),
                        "arguments": json.dumps(block.get("input") or {}),
                    },
                }
            )
    return {
        "role": "assistant",
        "content": "\n".join(text_parts),
        "tool_calls": tool_calls,
        "model": settings.model,
        "raw": data,
    }
