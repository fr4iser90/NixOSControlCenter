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
                out.append(
                    {
                        "kind": "tool",
                        "name": str(block.get("name") or "tool"),
                        "args": block.get("input") or {},
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
    ) -> Iterator[Event]:
        del session
        info = self.probe()
        if not info.available:
            yield {"kind": "error", "text": info.detail}
            yield {"kind": "done"}
            return

        bin_path = _qwen_bin()
        assert bin_path
        # Hint NCC MCP: user should register ncc-assistant as MCP in qwen settings.
        ncc_hint = (
            "When NixOS/NCC config tools are needed, prefer MCP server `ncc-assistant` "
            "if configured. Task:\n\n"
        )
        prompt = ncc_hint + text
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
                    yield {"kind": "assistant_delta", "text": line + "\n"}
                    reply_bits.append(line + "\n")
                    continue
                if not isinstance(obj, dict):
                    continue
                for ev in map_qwen_line(obj):
                    if ev.get("kind") == "assistant_delta":
                        reply_bits.append(str(ev.get("text") or ""))
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
        if rc != 0 and not reply_bits:
            yield {
                "kind": "error",
                "text": err.splitlines()[0][:400] if err else f"qwen exited {rc}",
            }
        elif reply_bits:
            joined = "".join(reply_bits).strip()
            if joined:
                yield {"kind": "assistant", "text": joined[-4000:], "streamed": True}
        yield {"kind": "done"}
