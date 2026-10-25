"""LLM clients for the built-in chat loop (OpenAI-compatible + Anthropic)."""

from __future__ import annotations

import json
import threading
import time
from typing import Any, Iterator

import httpx

from core.store.config import Settings


class LLMError(RuntimeError):
    """LLM / gateway failure. ``status_code`` set for HTTP errors when known."""

    def __init__(self, message: str, *, status_code: int | None = None) -> None:
        super().__init__(message)
        self.status_code = status_code

    @property
    def is_auth(self) -> bool:
        if self.status_code in (401, 403):
            return True
        return is_auth_failure_message(str(self))


class CancelledError(LLMError):
    pass


def _request_timeout() -> httpx.Timeout:
    """User-pref wall clock for chat/completions (connect capped at 30s)."""
    try:
        from core.store.preferences import get_llm_timeout_sec

        total = float(get_llm_timeout_sec())
    except Exception:
        total = 300.0
    return httpx.Timeout(total, connect=min(30.0, total))


def _max_attempts() -> int:
    try:
        from core.store.preferences import get_llm_retries

        return 1 + max(0, int(get_llm_retries()))
    except Exception:
        return 2


def _is_transient_llm_error(exc: BaseException) -> bool:
    if isinstance(exc, (httpx.TimeoutException, httpx.TransportError)):
        return True
    if isinstance(exc, LLMError):
        if exc.status_code in (408, 429, 500, 502, 503, 504):
            return True
        low = str(exc).lower()
        return any(
            t in low
            for t in ("timeout", "timed out", "temporarily", "rate limit", "503", "502")
        )
    return False


def is_auth_failure_message(message: str) -> bool:
    """True when a gateway error string indicates missing/expired API key."""
    low = (message or "").lower()
    if "http 401" in low or "http 403" in low:
        return True
    if " 401 " in low or " 403 " in low:
        return True
    return any(
        token in low
        for token in (
            "unauthorized",
            "forbidden",
            "invalid api key",
            "invalid_api_key",
            "auth failed",
            "auth required",
            "llm auth failed",
        )
    )


def _format_http_error(settings: Settings, status: int, body: str) -> str:
    """Humanize gateway errors (e.g. nginx HTML 500) — not NCC knowledge bugs."""
    text = (body or "").strip()
    snippet = text[:500]
    looks_html = "<html" in text.lower() or "<center>" in text.lower()
    where = (settings.endpoint or "?").rstrip("/")
    if status in (401, 403):
        return (
            f"LLM auth failed (HTTP {status}) at {where}\n\n"
            "The cached API key is missing, expired, or rejected by the provider.\n"
            "Update the key (Chat → auth prompt, or Settings → provider credentials).\n"
            "Model list cannot refresh until auth succeeds — "
            "an old selection may be stale."
        )
    if looks_html and status >= 500:
        return (
            f"LLM gateway HTTP {status} at {where}\n\n"
            "This is the reverse proxy / LLM server (nginx HTML), not the NCC knowledge pack.\n"
            "Check that the OpenAI-compatible upstream behind that URL is healthy "
            "(e.g. curl \"$ENDPOINT/models\").\n\n"
            f"Body (truncated):\n{snippet}"
        )
    return f"LLM HTTP {status} at {where}:\n{snippet}"


def _auth_headers(settings: Settings) -> dict[str, str]:
    headers = {k: v for k, v in (settings.extra_headers or ()) if k and v}
    if not settings.api_key:
        return headers
    name = (settings.api_header_name or "").strip()
    if not name or name.lower() == "authorization":
        headers["Authorization"] = f"Bearer {settings.api_key}"
    else:
        headers[name] = settings.api_key
    return headers


# --- token accounting -------------------------------------------------------

_INPUT_TOKEN_KEYS = ("prompt_tokens", "input_tokens", "prompt_eval_count")
_OUTPUT_TOKEN_KEYS = ("completion_tokens", "output_tokens", "eval_count")


def _token_int(raw: dict[str, Any], keys: tuple[str, ...]) -> int:
    for key in keys:
        value = raw.get(key)
        if isinstance(value, bool) or not isinstance(value, (int, float)):
            continue
        if value >= 0:
            return int(value)
    return 0


def normalize_usage(raw: Any) -> dict[str, int]:
    """Map OpenAI / Anthropic / Ollama usage spellings onto {input,output,total}.

    Gateways disagree on names (prompt_tokens vs input_tokens vs
    prompt_eval_count) and some omit total_tokens, so callers work off this
    shape instead of the provider payload.
    """
    if not isinstance(raw, dict):
        return {}
    inp = _token_int(raw, _INPUT_TOKEN_KEYS)
    out = _token_int(raw, _OUTPUT_TOKEN_KEYS)
    total = _token_int(raw, ("total_tokens",))
    if not total and (inp or out):
        total = inp + out
    if not inp and total >= out:
        inp = total - out
    if not total:
        return {}
    return {"input": inp, "output": out, "total": total}


# --- context window ---------------------------------------------------------

CONTEXT_WINDOW_CACHE: dict[str, dict[str, Any]] = {}
_STREAM_OPTIONS_REJECTORS: set[str] = set()

_WINDOW_KEYS_RUN = ("n_ctx", "num_ctx", "n_ctx_train")
_WINDOW_KEYS_MODEL = ("context_length", "max_model_len", "context_window")


def _ollama_base(endpoint: str) -> str:
    u = (endpoint or "").strip().rstrip("/")
    if u.endswith("/v1"):
        return u[: -len("/v1")]
    return u


def _window_from_value(value: Any) -> int:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return 0
    n = int(value)
    return n if 256 <= n <= 100_000_000 else 0


def _window_from_modelfile(text: str) -> int:
    """`num_ctx 4096` in an Ollama Modelfile/PARAMETERS blob is the real cap."""
    import re

    m = re.search(r"(?:^|[\s,;(\"'])num_ctx[\s=]+(\d+)", text or "")
    return _window_from_value(int(m.group(1))) if m else 0


def _window_from_mapping(payload: Any, keys: tuple[str, ...]) -> int:
    if not isinstance(payload, dict):
        return 0
    for key in keys:
        n = _window_from_value(payload.get(key))
        if n:
            return n
    for nested in ("meta", "details", "parameters"):
        data = payload.get(nested)
        if isinstance(data, dict):
            n = _window_from_mapping(data, keys)
            if n:
                return n
        elif isinstance(data, str):
            n = _window_from_modelfile(data)
            if n:
                return n
    return 0


def _window_from_model_info(model_info: Any) -> int:
    """Ollama nests `llama.context_length` — that is the trained length."""
    if not isinstance(model_info, dict):
        return 0
    best = 0
    for key, value in model_info.items():
        if str(key).endswith("context_length") or str(key).endswith("max_model_len"):
            best = max(best, _window_from_value(value))
    return best


def detect_context_window(
    settings: Settings, *, timeout: float = 5.0, use_cache: bool = True
) -> dict[str, Any] | None:
    """Best-effort "{tokens, source}" for the live model. Never raises.

    Runtime caps (llama.cpp n_ctx, Ollama num_ctx) win over the trained
    context_length: asking for 32k against a runtime num_ctx of 4k fails at
    request time, which is exactly the failure this number must predict.
    """
    if settings.api == "anthropic":
        return None
    cache_key = f"{settings.endpoint}|{settings.model or ''}"
    if use_cache and cache_key in CONTEXT_WINDOW_CACHE:
        return CONTEXT_WINDOW_CACHE[cache_key]

    base = _ollama_base(settings.endpoint)
    headers = _auth_headers(settings)
    found: dict[str, Any] | None = None
    try:
        with httpx.Client(timeout=timeout) as client:
            model = settings.model or ""
            if not model:
                try:
                    model = resolve_model(settings, client)
                except (LLMError, httpx.HTTPError):
                    model = ""

            for path in ("/props", "/v1/props"):
                try:
                    resp = client.get(f"{base}{path}", headers=headers)
                except httpx.HTTPError:
                    continue
                if resp.status_code != 200:
                    continue
                try:
                    props = resp.json()
                except (ValueError, TypeError):
                    continue
                n = _window_from_mapping(props, _WINDOW_KEYS_RUN)
                if n:
                    found = {"tokens": n, "source": f"{path} n_ctx"}
                    break

            if found is None and model:
                try:
                    resp = client.post(
                        f"{base}/api/show", headers=headers, json={"name": model}
                    )
                except httpx.HTTPError:
                    resp = None
                if resp is not None and resp.status_code == 200:
                    try:
                        show = resp.json()
                    except (ValueError, TypeError):
                        show = {}
                    n = _window_from_modelfile(str(show.get("parameters") or ""))
                    if n:
                        found = {"tokens": n, "source": "ollama num_ctx"}
                    else:
                        n = _window_from_model_info(show.get("model_info"))
                        if n:
                            found = {"tokens": n, "source": "ollama context_length"}

            if found is None:
                try:
                    resp = client.get(
                        f"{settings.endpoint.rstrip('/')}/models", headers=headers
                    )
                except httpx.HTTPError:
                    resp = None
                if resp is not None and resp.status_code == 200:
                    try:
                        data = resp.json()
                    except (ValueError, TypeError):
                        data = {}
                    entries = data.get("data") or data.get("models") or []
                    for entry in entries:
                        if not isinstance(entry, dict):
                            continue
                        if model and (entry.get("id") or entry.get("name")) != model:
                            continue
                        n = _window_from_mapping(entry, _WINDOW_KEYS_MODEL)
                        if n:
                            found = {"tokens": n, "source": "/models metadata"}
                            break
    except httpx.HTTPError:
        found = None

    if found is not None and use_cache:
        CONTEXT_WINDOW_CACHE[cache_key] = found
    return found


_CONTEXT_LENGTH_MARKERS = (
    "context_length_exceeded",
    "context length",
    "context window",
    "maximum context",
    "exceeds the available context",
    "too many tokens",
    "prompt is too long",
    "input is too long",
    "reduce the length",
    "num_ctx",
)


def is_context_length_error(exc: BaseException) -> bool:
    """True when the gateway refused the prompt for being too long."""
    if isinstance(exc, LLMError) and exc.status_code not in (None, 400, 413):
        return False
    low = str(exc).lower()
    return any(marker in low for marker in _CONTEXT_LENGTH_MARKERS)


def _rejects_stream_options(exc: BaseException) -> bool:
    """Gateways that choke on stream_options.include_usage answer 400 about it."""
    low = str(exc).lower()
    if "stream_options" in low or "include_usage" in low:
        return True
    return "unknown field" in low or "unsupported field" in low



def list_models(settings: Settings) -> list[dict[str, Any]]:
    """Return model dicts from GET {endpoint}/models (id + raw metadata)."""
    if settings.api == "anthropic":
        mid = settings.model or "claude-sonnet-4-20250514"
        return [{"id": mid, "owned_by": "anthropic", "vision": False}]

    url = f"{settings.endpoint}/models"
    try:
        # Short timeout — UI must not freeze if the gateway is slow/500.
        with httpx.Client(timeout=5.0) as client:
            resp = client.get(url, headers=_auth_headers(settings))
            if resp.status_code >= 400:
                raise LLMError(
                    _format_http_error(settings, resp.status_code, resp.text),
                    status_code=resp.status_code,
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

    OpenAI-compatible: stream first. If the gateway rejects streaming, one
    non-streaming POST with the same tools (not a silent tool-strip).
    """
    if settings.api == "anthropic":
        reply = _anthropic(settings, messages, tools)
        if reply.get("content"):
            yield {"type": "delta", "text": reply["content"]}
        yield {"type": "done", "message": reply}
        return

    attempts = _max_attempts()
    stream_rejected = False
    for attempt in range(attempts):
        emitted = False
        try:
            for ev in _openai_stream(settings, messages, tools, cancel_event):
                emitted = True
                yield ev
            return
        except CancelledError:
            raise
        except LLMError as exc:
            if cancel_event and cancel_event.is_set():
                raise CancelledError("cancelled") from exc
            if emitted:
                raise
            if _stream_rejected(exc):
                stream_rejected = True
                break
            if _is_transient_llm_error(exc) and attempt + 1 < attempts:
                time.sleep(min(2.0, 0.4 * (attempt + 1)))
                continue
            raise

    # Non-streaming fallback (gateway rejected SSE) — also honor retries.
    last_exc: BaseException | None = None
    for attempt in range(attempts if stream_rejected else 1):
        try:
            reply = _openai_compatible(settings, messages, tools)
            if reply.get("content"):
                yield {"type": "delta", "text": reply["content"]}
            yield {"type": "done", "message": reply}
            return
        except CancelledError:
            raise
        except LLMError as exc:
            last_exc = exc
            if _is_transient_llm_error(exc) and attempt + 1 < attempts:
                time.sleep(min(2.0, 0.4 * (attempt + 1)))
                continue
            raise
    if last_exc is not None:
        raise last_exc


def _stream_rejected(exc: LLMError) -> bool:
    """True when SSE/stream failed — use a normal non-streaming POST instead."""
    msg = str(exc).lower()
    return any(
        k in msg
        for k in (
            "stream",
            "sse",
            "400",
            "404",
            "405",
            "413",
            "415",
            "500",
            "502",
            "503",
            "504",
            "501",
            "gateway",
            "nginx",
            "not implemented",
            "unsupported",
            "internal server",
        )
    )


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
    if stream and model not in _STREAM_OPTIONS_REJECTORS:
        # Without this, streaming responses carry no usage at all and context
        # accounting would have to stay a pure estimate.
        payload["stream_options"] = {"include_usage": True}
    return payload


def _openai_compatible(
    settings: Settings,
    messages: list[dict[str, Any]],
    tools: list[dict[str, Any]] | None,
) -> dict[str, Any]:
    url = f"{settings.endpoint}/chat/completions"
    headers = {"Content-Type": "application/json", **_auth_headers(settings)}

    with httpx.Client(timeout=_request_timeout()) as client:
        model = resolve_model(settings, client)
        payload = _openai_payload(settings, model, messages, tools, stream=False)
        resp = client.post(url, headers=headers, json=payload)
        if resp.status_code >= 400:
            raise LLMError(
                _format_http_error(settings, resp.status_code, resp.text),
                status_code=resp.status_code,
            )
        data = resp.json()

    choice = (data.get("choices") or [{}])[0]
    message = choice.get("message") or {}
    return {
        "role": "assistant",
        "content": message.get("content") or "",
        "tool_calls": message.get("tool_calls") or [],
        "model": model,
        "usage": normalize_usage(data.get("usage")),
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

    with httpx.Client(timeout=_request_timeout()) as client:
        model_name = resolve_model(settings, client)
        for attempt in range(2):
            payload = _openai_payload(settings, model_name, messages, tools, stream=True)
            try:
                yield from _openai_stream_body(
                    settings, client, url, headers, payload, cancel_event, model_name
                )
                return
            except LLMError as exc:
                # Only reachable before the first chunk, so nothing is doubled.
                if (
                    attempt == 0
                    and model_name not in _STREAM_OPTIONS_REJECTORS
                    and _rejects_stream_options(exc)
                ):
                    _STREAM_OPTIONS_REJECTORS.add(model_name)
                    continue
                raise


def _openai_stream_body(
    settings: Settings,
    client: httpx.Client,
    url: str,
    headers: dict[str, str],
    payload: dict[str, Any],
    cancel_event: threading.Event | None,
    model_name: str,
) -> Iterator[dict[str, Any]]:
    content_parts: list[str] = []
    tool_acc: dict[int, dict[str, Any]] = {}
    usage: dict[str, int] = {}

    with client.stream("POST", url, headers=headers, json=payload) as resp:
        if resp.status_code >= 400:
            body = resp.read().decode("utf-8", errors="replace")
            raise LLMError(
                _format_http_error(settings, resp.status_code, body),
                status_code=resp.status_code,
            )

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
            if chunk.get("usage"):
                usage = normalize_usage(chunk["usage"]) or usage
            choice = (chunk.get("choices") or [{}])[0]
            delta = choice.get("delta") or {}
            # OpenAI-compat / DeepSeek / Qwen reasoning channels
            thinking = (
                delta.get("reasoning_content")
                or delta.get("reasoning")
                or delta.get("thinking")
            )
            if thinking:
                yield {"type": "thinking_delta", "text": str(thinking)}
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
            "usage": usage,
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
        "usage": normalize_usage(data.get("usage")),
        "raw": data,
    }
