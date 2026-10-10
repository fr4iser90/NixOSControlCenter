"""Qwen Code harness — headless ``qwen -p … --output-format stream-json``."""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import threading
from typing import Any, Iterator

from .types import Event, HarnessInfo


def _qwen_bin() -> str | None:
    override = (os.environ.get("NCC_ASSISTANT_QWEN_BIN") or "").strip()
    if override:
        return override if os.path.isfile(override) or shutil.which(override) else None
    return shutil.which("qwen")


def _text_from_message_content(content: Any) -> str:
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts: list[str] = []
        for block in content:
            if isinstance(block, str):
                parts.append(block)
            elif isinstance(block, dict):
                if block.get("type") in ("text", "output_text") and block.get("text"):
                    parts.append(str(block["text"]))
                elif block.get("thinking") or block.get("type") == "thinking":
                    # handled separately
                    pass
        return "".join(parts)
    return str(content)


def _thinking_from_message(message: dict[str, Any]) -> str:
    content = message.get("content")
    if isinstance(content, list):
        bits: list[str] = []
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") in ("thinking", "reasoning"):
                bits.append(str(block.get("thinking") or block.get("text") or ""))
            elif block.get("thinking"):
                bits.append(str(block["thinking"]))
        return "".join(bits)
    for key in ("reasoning_content", "reasoning", "thinking"):
        if message.get(key):
            return str(message[key])
    return ""


TOOL_ECHO_MARKERS = ('<tool_call>', '</tool_call>', "<function=", "<parameter=")


def tool_echo_in_text(text: str) -> bool:
    """True when a text block carries tool syntax instead of a structured call.

    A model whose endpoint skips native function calling writes the call in its
    trained XML grammar. Rendering that as an answer makes a run that executed
    nothing look like a finished tool round, so it must never reach the reply.
    """
    low = (text or "").lower()
    return any(marker in low for marker in TOOL_ECHO_MARKERS)


def tool_echo_notice(text: str, limit: int = 400) -> str:
    """Notice text: what happened, how many calls, and what the model asked for."""
    body = " ".join((text or "").split())
    low = (text or "").lower()
    calls = max(low.count('<tool_call>'), low.count('</tool_call>')) or 1
    head = (
        f"{calls} tool call{'s' if calls != 1 else ''} echoed as text — nothing was executed. "
        "The model wrote tool syntax into its reply instead of a structured "
        "tool_use block, so this harness had nothing to run."
    )
    if not body:
        return head
    return f"{head}\n\nEchoed: {body[:limit]}{'…' if len(body) > limit else ''}"


def map_qwen_line(obj: dict[str, Any]) -> list[Event]:
    """Map one Qwen stream-json object → zero or more NCC events."""
    out: list[Event] = []
    typ = str(obj.get("type") or "")

    if typ == "stream_event":
        ev = obj.get("event") or {}
        et = str(ev.get("type") or "")
        if et == "content_block_delta":
            delta = ev.get("delta") or {}
            dtyp = str(delta.get("type") or "")
            text = delta.get("text") or delta.get("thinking") or ""
            if text and dtyp in ("thinking_delta", "reasoning_delta"):
                out.append({"kind": "thinking_delta", "text": str(text)})
            elif text and dtyp in ("text_delta", "input_json_delta", ""):
                if dtyp == "input_json_delta":
                    out.append({"kind": "status", "text": "tool args…", "phase": "tool"})
                else:
                    out.append({"kind": "assistant_delta", "text": str(text)})
        elif et == "content_block_start":
            block = ev.get("content_block") or {}
            if block.get("type") in ("tool_use", "tool_call"):
                name = str(block.get("name") or "tool")
                args = block.get("input") or {}
                out.append({"kind": "tool", "name": name, "args": args})
                low = name.lower()
                if any(x in low for x in ("task", "subagent", "delegate", "spawn")):
                    out.append(
                        {
                            "kind": "run_spawn",
                            "name": name,
                            "title": str(
                                (args.get("description") if isinstance(args, dict) else None)
                                or (args.get("prompt") if isinstance(args, dict) else None)
                                or name
                            )[:40],
                            "goal": str(
                                (args.get("prompt") if isinstance(args, dict) else None)
                                or (args.get("goal") if isinstance(args, dict) else None)
                                or ""
                            ),
                            "focus": False,
                        }
                    )
        return out

    if typ == "assistant":
        msg = obj.get("message") or obj
        if not isinstance(msg, dict):
            msg = {}
        think = _thinking_from_message(msg)
        if think:
            out.append({"kind": "thinking_delta", "text": think})
        text = _text_from_message_content(msg.get("content"))
        if text.strip():
            out.append({"kind": "assistant_delta", "text": text})
            out.append({"kind": "assistant", "text": text, "streamed": True})
        # tool_use blocks
        content = msg.get("content")
        if isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") in (
                    "tool_use",
                    "tool_call",
                ):
                    out.append(
                        {
                            "kind": "tool",
                            "name": str(block.get("name") or "tool"),
                            "args": block.get("input") or {},
                        }
                    )
        return out

    if typ in ("tool_result", "user"):
        # tool results often arrive as user tool_result content
        msg = obj.get("message") or obj
        content = msg.get("content") if isinstance(msg, dict) else None
        if isinstance(content, list):
            for block in content:
                if isinstance(block, dict) and block.get("type") == "tool_result":
                    payload = block.get("content") or block.get("output") or ""
                    if isinstance(payload, list):
                        payload = _text_from_message_content(payload)
                    out.append(
                        {
                            "kind": "tool_result",
                            "name": str(block.get("tool_use_id") or "tool"),
                            "text": str(payload)[:4000],
                        }
                    )
        return out

    if typ == "result":
        result = obj.get("result")
        if result:
            out.append({"kind": "assistant", "text": str(result), "streamed": False})
        if obj.get("is_error"):
            out.append({"kind": "error", "text": str(obj.get("error") or result or "qwen error")})
        return out

    if typ == "system":
        subtype = str(obj.get("subtype") or "")
        if subtype:
            out.append({"kind": "status", "text": f"qwen:{subtype}", "phase": "llm"})
        return out

    return out


class QwenHarness:
    name = "qwen"

    def probe(self) -> HarnessInfo:
        bin_path = _qwen_bin()
        if not bin_path:
            return HarnessInfo(
                name=self.name,
                label="Qwen Code",
                available=False,
                detail=(
                    "qwen not on PATH — prefer standalone install or "
                    "TMPDIR=$HOME/tmp npm i -g @qwen-code/qwen-code "
                    "(avoid filling tmpfs /tmp; Node ≥22). "
                    "Or: NCC_ASSISTANT_QWEN_BIN=/path/to/qwen"
                ),
            )
        return HarnessInfo(
            name=self.name,
            label="Qwen Code",
            available=True,
            detail=f"binary: {bin_path}",
        )

    def send(
        self,
        text: str,
        *,
        cwd: str | None = None,
        cancel_event: threading.Event | None = None,
        session: Any | None = None,
        history: list[dict[str, Any]] | None = None,
    ) -> Iterator[Event]:
        del session
        info = self.probe()
        if not info.available:
            yield {"kind": "error", "text": info.detail}
            yield {"kind": "done"}
            return

        from .mcp_inject import ensure_qwen_ncc_mcp

        inject = ensure_qwen_ncc_mcp()
        if inject.get("status") in ("created", "updated"):
            yield {
                "kind": "status",
                "text": f"MCP: {inject.get('detail')}",
                "phase": "setup",
            }

        bin_path = _qwen_bin()
        assert bin_path
        ncc_hint = (
            "When NixOS/NCC config tools are needed, prefer MCP server `ncc-assistant` "
            "if configured.\n\n"
        )
        hist_bits: list[str] = []
        for turn in (history or [])[-12:]:
            if not isinstance(turn, dict):
                continue
            role = str(turn.get("role") or "")
            content = str(turn.get("content") or "").strip()
            if not content:
                continue
            hist_bits.append(f"{role.capitalize()}: {content[:1500]}")
        hist_block = ""
        if hist_bits:
            hist_block = "Prior conversation:\n" + "\n".join(hist_bits) + "\n\n"
        prompt = ncc_hint + hist_block + "Current task:\n" + text
        cmd = [
            bin_path,
            "-p",
            prompt,
            "--output-format",
            "stream-json",
            "--include-partial-messages",
        ]
        yield {"kind": "user", "text": text}
        yield {"kind": "status", "text": "Qwen Code…", "phase": "llm"}
        yield {"kind": "assistant_start"}

        try:
            proc = subprocess.Popen(
                cmd,
                cwd=cwd or os.getcwd(),
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1,
            )
        except OSError as exc:
            yield {"kind": "error", "text": f"Failed to start qwen: {exc}"}
            yield {"kind": "done"}
            return

        assert proc.stdout is not None
        reply_bits: list[str] = []
        echo_bits: list[str] = []
        emitted_reply = False
        last_reply = ""
        try:
            for line in proc.stdout:
                if cancel_event is not None and cancel_event.is_set():
                    proc.terminate()
                    yield {"kind": "error", "text": "Generation cancelled."}
                    yield {"kind": "done"}
                    return
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    # plain text fallback
                    piece = line + "\n"
                    if tool_echo_in_text(piece):
                        echo_bits.append(piece)
                    else:
                        yield {"kind": "assistant_delta", "text": piece}
                        reply_bits.append(piece)
                    continue
                if not isinstance(obj, dict):
                    continue
                for ev in map_qwen_line(obj):
                    ev_kind = str(ev.get("kind") or "")
                    if ev_kind == "assistant_delta":
                        piece = str(ev.get("text") or "")
                        if tool_echo_in_text(piece):
                            # The notice below shows the echo; the answer must stay clean.
                            echo_bits.append(piece)
                            continue
                        reply_bits.append(piece)
                    elif ev_kind == "assistant":
                        text = str(ev.get("text") or "")
                        if tool_echo_in_text(text):
                            echo_bits.append(text)
                            continue
                        if emitted_reply and text.strip() == last_reply.strip():
                            # One turn arrives as message object, result object, and
                            # the join of its deltas; surfaces open a bubble per event.
                            continue
                        emitted_reply = True
                        last_reply = text
                    yield ev
            rc = proc.wait(timeout=5)
        except Exception as exc:  # noqa: BLE001
            proc.kill()
            yield {"kind": "error", "text": str(exc)}
            yield {"kind": "done"}
            return

        err = ""
        if proc.stderr is not None:
            err = (proc.stderr.read() or "").strip()
        echoed = "".join(echo_bits)
        if rc != 0 and not reply_bits and not echoed:
            yield {
                "kind": "error",
                "text": err.splitlines()[0][:400] if err else f"qwen exited {rc}",
            }
        if tool_echo_in_text(echoed):
            yield {
                "kind": "protocol_error",
                "text": tool_echo_notice(echoed),
                # Tells a surface that streamed this echo to drop what it shows.
                "drop_live_reply": True,
            }
        elif reply_bits and not emitted_reply:
            joined = "".join(reply_bits).strip()
            if joined:
                yield {"kind": "assistant", "text": joined[-4000:], "streamed": True}
        yield {"kind": "done"}
