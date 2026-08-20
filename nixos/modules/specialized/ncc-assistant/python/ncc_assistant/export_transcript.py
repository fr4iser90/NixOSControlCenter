"""Export sessions and jobs to markdown format."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any

from .audit import redact_secrets, redact_dict
from .history import load_session, session_path
from .jobs import get_job_store, JobMeta


def _format_timestamp(iso_str: str | None) -> str:
    """Format ISO timestamp to readable string."""
    if not iso_str:
        return ""
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        return dt.strftime("%Y-%m-%d %H:%M:%S UTC")
    except ValueError:
        return iso_str


def _redact_message_content(content: Any) -> Any:
    """Redact sensitive content from message."""
    if isinstance(content, str):
        return redact_secrets(content)
    if isinstance(content, list):
        result = []
        for item in content:
            if isinstance(item, dict):
                if item.get("type") == "image_url":
                    result.append({"type": "text", "text": "[image omitted]"})
                elif item.get("type") == "text":
                    result.append({"type": "text", "text": redact_secrets(item.get("text", ""))})
                else:
                    result.append(redact_dict(item))
            else:
                result.append(item)
        return result
    return content


def export_session_markdown(
    session_id: str,
    *,
    redact: bool = True,
    include_tool_results: bool = True,
) -> str:
    """Export a chat session to markdown format."""
    from .transcript import format_messages_markdown

    data = load_session(session_id)
    if not data:
        return f"# Session Not Found\n\nSession `{session_id}` not found.\n"

    meta: list[str] = [
        f"# {data.get('title', 'Untitled Session')}",
        "",
        f"**Session ID:** `{session_id}`",
        f"**Model:** {data.get('model', 'unknown')}",
        f"**Endpoint:** {data.get('endpoint', 'unknown')}",
    ]
    if data.get("created"):
        meta.append(f"**Created:** {_format_timestamp(data.get('created'))}")
    if data.get("updated"):
        meta.append(f"**Updated:** {_format_timestamp(data.get('updated'))}")
    meta.extend(["", "---", ""])

    raw_messages = list(data.get("messages") or [])
    if redact:
        messages: list[dict[str, Any]] = []
        for msg in raw_messages:
            if not isinstance(msg, dict):
                continue
            m = dict(msg)
            m["content"] = _redact_message_content(m.get("content"))
            if m.get("role") == "tool" and isinstance(m.get("content"), str):
                m["content"] = redact_secrets(m["content"])
            messages.append(m)
    else:
        messages = [m for m in raw_messages if isinstance(m, dict)]

    body = format_messages_markdown(
        messages,
        include_system=True,
        include_tools=include_tool_results,
        title=None,
    )
    return "\n".join(meta) + body


def export_job_markdown(
    job_id: str,
    *,
    redact: bool = True,
    include_events: bool = True,
) -> str:
    """Export a job to markdown format."""
    store = get_job_store()
    meta = store.get(job_id)

    if not meta:
        return f"# Job Not Found\n\nJob `{job_id}` not found.\n"

    lines: list[str] = []
    lines.append(f"# Job: {job_id}")
    lines.append("")
    lines.append(f"**Goal:** {meta.goal}")
    lines.append(f"**Status:** {meta.status}")
    if meta.profile:
        lines.append(f"**Profile:** {meta.profile}")
    if meta.playbook:
        lines.append(f"**Playbook:** {meta.playbook}")
    lines.append(f"**Dry Run:** {meta.dry_run}")
    lines.append(f"**Steps:** {meta.step_count}")
    lines.append(f"**Created:** {_format_timestamp(meta.created_at)}")
    if meta.started_at:
        lines.append(f"**Started:** {_format_timestamp(meta.started_at)}")
    if meta.finished_at:
        lines.append(f"**Finished:** {_format_timestamp(meta.finished_at)}")
    if meta.error:
        lines.append(f"**Error:** {redact_secrets(meta.error) if redact else meta.error}")
    lines.append("")
    lines.append("---")
    lines.append("")

    result = store.get_result(job_id)
    if result:
        lines.append("## Result")
        lines.append("")
        lines.append(f"**Success:** {result.success}")
        if result.summary:
            summary = redact_secrets(result.summary) if redact else result.summary
            lines.append(f"**Summary:** {summary}")
        if result.error:
            error = redact_secrets(result.error) if redact else result.error
            lines.append(f"**Error:** {error}")
        lines.append("")

    if include_events:
        lines.append("## Event Log")
        lines.append("")
        for event in store.get_events(job_id):
            ts = _format_timestamp(event.timestamp)
            kind = event.kind
            data = event.data

            if redact and data:
                data = redact_dict(data)

            if kind == "step":
                lines.append(f"### Step {data.get('step', '?')} - {ts}")
                lines.append("")
            elif kind == "tool":
                name = data.get("name", "unknown")
                args = data.get("args", {})
                lines.append(f"**Tool:** `{name}`")
                lines.append("```json")
                lines.append(json.dumps(args, indent=2)[:1000])
                lines.append("```")
            elif kind == "tool_result":
                content = str(data.get("content", ""))[:1000]
                lines.append("**Result:**")
                lines.append("```")
                lines.append(content)
                lines.append("```")
            elif kind == "assistant":
                text = data.get("text", "")
                if text:
                    lines.append(f"**Assistant:** {text[:500]}")
            elif kind == "error":
                error = data.get("text", data.get("error", ""))
                lines.append(f"**Error:** {error}")
            elif kind == "status":
                status = data.get("text", "")
                lines.append(f"*Status: {status}*")
            lines.append("")

    return "\n".join(lines)


def export_to_file(
    content: str,
    output_path: Path | str,
) -> Path:
    """Write export content to a file."""
    path = Path(output_path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


def export_latest(*, kind: str = "session") -> Path:
    """Export the most recently updated session or job to ~/Documents or config dir."""
    from .history import list_sessions
    from .jobs import get_job_store

    out_dir = config_home() / "exports"
    out_dir.mkdir(parents=True, exist_ok=True)

    if kind == "job":
        store = get_job_store()
        jobs = store.list_jobs() if hasattr(store, "list_jobs") else []
        if not jobs:
            # try list()
            jobs = store.list() if hasattr(store, "list") else []
        if not jobs:
            raise FileNotFoundError("No jobs to export")
        job = jobs[0]
        jid = job.id if hasattr(job, "id") else job.get("id")
        content = export_job_markdown(str(jid))
        path = out_dir / f"job-{jid}.md"
    else:
        sessions = list_sessions(limit=1)
        if not sessions:
            raise FileNotFoundError("No sessions to export")
        sid = sessions[0]["id"]
        content = export_session_markdown(sid)
        path = out_dir / f"session-{sid}.md"
    return export_to_file(content, path)
