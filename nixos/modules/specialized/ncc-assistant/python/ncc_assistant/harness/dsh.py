"""DeepSeek Harness — ``dsh --profile headless "task"`` (reasoning on stderr)."""

from __future__ import annotations

import os
import shutil
import subprocess
import threading
from typing import Any, Iterator

from .types import Event, HarnessInfo


def _dsh_bin() -> str | None:
    override = (os.environ.get("NCC_ASSISTANT_DSH_BIN") or "").strip()
    if override:
        return override if os.path.isfile(override) or shutil.which(override) else None
    found = shutil.which("dsh")
    if found:
        return found
    # npx fallback marker — caller may use npx @deepseek-ai/dsh
    return None


def _npx_dsh_cmd(task: str) -> list[str] | None:
    if not shutil.which("npx"):
        return None
    return ["npx", "--yes", "@deepseek-ai/dsh", "--profile", "headless", task]


class DshHarness:
    name = "dsh"

    def probe(self) -> HarnessInfo:
        bin_path = _dsh_bin()
        if bin_path:
            return HarnessInfo(
                name=self.name,
                label="DeepSeek Harness",
                available=True,
                detail=f"binary: {bin_path}",
            )
        if shutil.which("npx"):
            return HarnessInfo(
                name=self.name,
                label="DeepSeek Harness",
                available=True,
                detail="via npx @deepseek-ai/dsh (developer preview)",
            )
        return HarnessInfo(
            name=self.name,
            label="DeepSeek Harness",
            available=False,
            detail="dsh/npx missing — install Node then: npx @deepseek-ai/dsh web (preview)",
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

        from .mcp_inject import ensure_dsh_ncc_mcp

        inject = ensure_dsh_ncc_mcp()
        if inject.get("status") in ("created", "updated"):
            yield {
                "kind": "status",
                "text": f"MCP: {inject.get('detail')}",
                "phase": "setup",
            }

        ncc_hint = (
            "Prefer MCP `ncc-assistant` for NixOS Control Center tools when available.\n\n"
        )
        hist_bits: list[str] = []
        for turn in (history or [])[-12:]:
            if not isinstance(turn, dict):
                continue
            role = str(turn.get("role") or "")
            content = str(turn.get("content") or "").strip()
            if content:
                hist_bits.append(f"{role.capitalize()}: {content[:1500]}")
        hist_block = (
            ("Prior conversation:\n" + "\n".join(hist_bits) + "\n\n") if hist_bits else ""
        )
        task = ncc_hint + hist_block + "Current task:\n" + text
        bin_path = _dsh_bin()
        if bin_path:
            cmd = [bin_path, "--profile", "headless", task]
        else:
            cmd = _npx_dsh_cmd(task)
            if cmd is None:
                yield {"kind": "error", "text": "No dsh or npx available"}
                yield {"kind": "done"}
                return

        yield {"kind": "user", "text": text}
        yield {"kind": "status", "text": "DeepSeek Harness…", "phase": "llm"}
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
            yield {"kind": "error", "text": f"Failed to start dsh: {exc}"}
            yield {"kind": "done"}
            return

        assert proc.stdout is not None
        assert proc.stderr is not None

        # Stream stderr reasoning concurrently via threads into queues would be
        # nicer; for v1 poll interleaved by reading stderr after/nonblocking.
        # Use a reader thread for reasoning lines.
        reasoning_q: list[str] = []
        stop = threading.Event()

        def _read_stderr() -> None:
            assert proc.stderr is not None
            for line in proc.stderr:
                if stop.is_set():
                    break
                line = line.rstrip("\n")
                if not line:
                    continue
                # dsh streams reasoning under "dsh: reasoning:" headings
                if "reasoning" in line.lower() or line.startswith("dsh:"):
                    cleaned = line
                    for prefix in ("dsh: reasoning:", "dsh:reasoning:", "dsh:"):
                        if cleaned.lower().startswith(prefix.lower()):
                            cleaned = cleaned[len(prefix) :].lstrip()
                            break
                    reasoning_q.append(cleaned + "\n")
                else:
                    reasoning_q.append(line + "\n")

        t = threading.Thread(target=_read_stderr, daemon=True)
        t.start()

        out_chunks: list[str] = []
        try:
            for line in proc.stdout:
                if cancel_event is not None and cancel_event.is_set():
                    proc.terminate()
                    yield {"kind": "error", "text": "Generation cancelled."}
                    yield {"kind": "done"}
                    return
                # Flush any reasoning collected so far
                while reasoning_q:
                    piece = reasoning_q.pop(0)
                    yield {"kind": "thinking_delta", "text": piece}
                if line:
                    out_chunks.append(line)
                    yield {"kind": "assistant_delta", "text": line}
            rc = proc.wait(timeout=10)
        except Exception as exc:  # noqa: BLE001
            proc.kill()
            yield {"kind": "error", "text": str(exc)}
            yield {"kind": "done"}
            return
        finally:
            stop.set()
            t.join(timeout=2)

        while reasoning_q:
            yield {"kind": "thinking_delta", "text": reasoning_q.pop(0)}

        final = "".join(out_chunks).strip()
        if final:
            yield {"kind": "assistant", "text": final, "streamed": True}
        elif rc != 0:
            yield {"kind": "error", "text": f"dsh exited {rc}"}
        yield {"kind": "done"}
