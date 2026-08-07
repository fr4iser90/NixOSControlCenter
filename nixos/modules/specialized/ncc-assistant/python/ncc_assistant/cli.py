"""CLI entry: ncc-assistant [gui|chat|mcp|agent|jobs|playbook|presence|approve|knowledge|export|eval|tools|serve-openapi|tray]."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from .auth import with_cached_credentials
from .chat import run_chat
from .config import Settings
from .runtime import TOOL_DEFINITIONS, ToolRuntime


def _cmd_tools(args: argparse.Namespace) -> int:
    """List available tools."""
    if getattr(args, "json", False):
        from .registry import get_registry
        registry = get_registry()
        tools = [
            {
                "name": t.name,
                "kind": t.kind,
                "description": t.description,
                "enabled": t.enabled,
                "source": t.source,
            }
            for t in registry.list_all()
        ]
        print(json.dumps(tools, indent=2))
    else:
        from .registry import get_registry
        registry = get_registry()
        for t in registry.list_all():
            status = "+" if t.enabled else "-"
            print(f"[{status}] {t.name:40} {t.kind:8} {t.description[:50]}")
    return 0


def _cmd_tool(args: argparse.Namespace) -> int:
    """Invoke a single tool."""
    settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
    runtime = ToolRuntime(settings)
    try:
        payload = json.loads(args.args)
    except json.JSONDecodeError as exc:
        print(f"Invalid --args JSON: {exc}", file=sys.stderr)
        return 2
    result = runtime.call(args.name, payload)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result.get("ok", True) else 1


def _cmd_agent_run(args: argparse.Namespace) -> int:
    """Run agent with a goal."""
    from .agent import run_agent

    settings = with_cached_credentials(Settings.from_env(client_mode="chat"))

    playbook_goal = None
    if args.playbook:
        from .playbooks import get_playbook
        pb = get_playbook(args.playbook)
        if not pb:
            print(f"Playbook not found: {args.playbook}", file=sys.stderr)
            return 1
        playbook_goal = pb.goal
        if not args.profile and pb.profile:
            args.profile = pb.profile
        if pb.dry_run:
            args.dry_run = True

    goal = args.goal or playbook_goal
    if not goal:
        print("Error: --goal or --playbook required", file=sys.stderr)
        return 1

    max_steps = args.max_steps or settings.agent_max_steps

    print(f"Starting agent with goal: {goal}")
    print(f"Max steps: {max_steps}, Dry run: {args.dry_run}, Profile: {args.profile or 'default'}")
    print("-" * 60)

    for event in run_agent(
        goal,
        settings,
        max_steps=max_steps,
        dry_run=args.dry_run,
        profile=args.profile,
        playbook=args.playbook,
    ):
        kind = event.get("kind")
        if kind == "job_started":
            print(f"Job started: {event.get('job_id')}")
        elif kind == "step":
            print(f"\n--- Step {event.get('step')}/{event.get('max_steps')} ---")
        elif kind == "assistant":
            print(f"Assistant: {event.get('text', '')[:500]}")
        elif kind == "tool":
            print(f"Tool: {event.get('name')}({json.dumps(event.get('args', {}))})")
        elif kind == "tool_result":
            text = event.get("text", "")
            print(f"Result: {text[:300]}{'...' if len(text) > 300 else ''}")
        elif kind == "agent_finish":
            print(f"\nAgent finished: {event.get('summary')}")
            print(f"Success: {event.get('success')}")
        elif kind == "error":
            print(f"Error: {event.get('text')}", file=sys.stderr)
        elif kind == "job_finished":
            print(f"\nJob {event.get('job_id')} completed (success={event.get('success')})")
        elif kind == "job_failed":
            print(f"\nJob {event.get('job_id')} failed: {event.get('error')}", file=sys.stderr)
        elif kind == "job_cancelled":
            print(f"\nJob {event.get('job_id')} cancelled")

    return 0


def _cmd_jobs_list(args: argparse.Namespace) -> int:
    """List jobs."""
    from .jobs import get_job_store
    store = get_job_store()
    jobs = store.list_jobs(limit=args.limit)

    if getattr(args, "json", False):
        print(json.dumps([j.to_dict() for j in jobs], indent=2))
    else:
        for job in jobs:
            status_icon = {"completed": "+", "failed": "!", "running": "*", "cancelled": "x"}.get(job.status, "?")
            print(f"[{status_icon}] {job.id}  {job.status:10} {job.goal[:40]}")
    return 0


def _cmd_jobs_show(args: argparse.Namespace) -> int:
    """Show job details."""
    from .jobs import get_job_store
    store = get_job_store()
    job = store.get(args.job_id)
    if not job:
        print(f"Job not found: {args.job_id}", file=sys.stderr)
        return 1
    print(json.dumps(job.to_dict(), indent=2))
    result = store.get_result(args.job_id)
    if result:
        print("\nResult:")
        print(json.dumps(result.to_dict(), indent=2))
    return 0


def _cmd_jobs_log(args: argparse.Namespace) -> int:
    """Show job event log."""
    from .jobs import get_job_store
    store = get_job_store()
    for event in store.get_events(args.job_id):
        print(f"[{event.timestamp}] {event.kind}: {json.dumps(event.data)[:200]}")
    return 0


def _cmd_playbook_list(args: argparse.Namespace) -> int:
    """List playbooks."""
    from .playbooks import list_playbooks
    playbooks = list_playbooks()

    if getattr(args, "json", False):
        print(json.dumps([p.to_dict() for p in playbooks], indent=2))
    else:
        for pb in playbooks:
            source = "builtin" if pb.source == "builtin" else "user"
            print(f"[{source:7}] {pb.name:30} {pb.description[:40]}")
    return 0


def _cmd_playbook_run(args: argparse.Namespace) -> int:
    """Run a playbook."""
    from .playbooks import get_playbook

    pb = get_playbook(args.name)
    if not pb:
        print(f"Playbook not found: {args.name}", file=sys.stderr)
        return 1

    run_args = argparse.Namespace(
        goal=pb.goal,
        max_steps=pb.max_steps,
        dry_run=args.dry_run if hasattr(args, "dry_run") else pb.dry_run,
        profile=pb.profile,
        playbook=args.name,
    )
    return _cmd_agent_run(run_args)


def _cmd_presence_status(args: argparse.Namespace) -> int:
    """Show presence status."""
    from .presence import get_presence
    presence = get_presence()
    print(json.dumps(presence.to_dict(), indent=2))
    return 0


def _cmd_presence_pause(args: argparse.Namespace) -> int:
    """Pause agent."""
    from .presence import pause
    presence = pause(reason=args.reason)
    print(f"Agent paused: {presence.state}")
    return 0


def _cmd_presence_resume(args: argparse.Namespace) -> int:
    """Resume agent."""
    from .presence import resume
    presence = resume(reason=args.reason)
    print(f"Agent resumed: {presence.state}")
    return 0


def _cmd_approve(args: argparse.Namespace) -> int:
    """Handle pending decisions."""
    from .notifications import get_decision_service

    service = get_decision_service()

    if args.action == "list":
        pending = service.list_pending()
        for d in pending:
            print(f"[{d.id}] {d.kind}: {d.title}")
            print(f"    {d.summary}")
        return 0

    if not args.decision_id:
        print("Error: decision_id required for allow/block", file=sys.stderr)
        return 1

    if args.action == "allow":
        result = service.allow(args.decision_id)
    else:
        result = service.block(args.decision_id)

    if result:
        print(f"Decision {args.decision_id}: {result.result}")
    else:
        print(f"Decision not found: {args.decision_id}", file=sys.stderr)
        return 1
    return 0


def _cmd_knowledge_sync(args: argparse.Namespace) -> int:
    """Sync knowledge overlay."""
    from .paths import knowledge_overlay_dir

    overlay = knowledge_overlay_dir()
    print(f"Knowledge overlay directory: {overlay}")

    if args.note:
        note_file = overlay / "user-notes.md"
        with note_file.open("a", encoding="utf-8") as f:
            f.write(f"\n- {args.note}\n")
        print(f"Added note to {note_file}")

    return 0


def _cmd_export_session(args: argparse.Namespace) -> int:
    """Export session to markdown."""
    from .export_transcript import export_session_markdown, export_to_file

    content = export_session_markdown(args.session_id, redact=not args.no_redact)

    if args.output:
        path = export_to_file(content, args.output)
        print(f"Exported to {path}")
    else:
        print(content)
    return 0


def _cmd_export_job(args: argparse.Namespace) -> int:
    """Export job to markdown."""
    from .export_transcript import export_job_markdown, export_to_file

    content = export_job_markdown(args.job_id, redact=not args.no_redact)

    if args.output:
        path = export_to_file(content, args.output)
        print(f"Exported to {path}")
    else:
        print(content)
    return 0


def _cmd_eval_run(args: argparse.Namespace) -> int:
    """Run evaluation harness."""
    from .eval_harness import EvalHarness, load_eval_cases

    settings = Settings.from_env(client_mode="chat")
    harness = EvalHarness(settings)

    cases_path = Path(args.cases) if args.cases else None
    cases = load_eval_cases(cases_path)

    if not cases:
        print("No evaluation cases found", file=sys.stderr)
        return 1

    print(f"Running {len(cases)} evaluation cases...")

    def on_result(result):
        status = "PASS" if result.passed else "FAIL"
        print(f"[{status}] {result.case_name} ({result.duration_ms:.0f}ms)")
        if not result.passed:
            for detail in result.details:
                print(f"       {detail}")
            if result.error:
                print(f"       Error: {result.error}")

    report = harness.run_all(cases, on_result=on_result)

    print(f"\nResults: {report.passed}/{report.total} passed, {report.failed} failed")

    if args.output:
        Path(args.output).write_text(json.dumps(report.to_dict(), indent=2), encoding="utf-8")
        print(f"Report written to {args.output}")

    return 0 if report.failed == 0 else 1


def _cmd_serve_openapi(args: argparse.Namespace) -> int:
    """Start minimal OpenAPI HTTP server."""
    import http.server
    import socketserver
    import os

    port = args.port
    token = args.token or os.environ.get("NCC_ASSISTANT_HTTP_TOKEN", "")

    class Handler(http.server.SimpleHTTPRequestHandler):
        def do_GET(self):
            if token and self.headers.get("Authorization") != f"Bearer {token}":
                self.send_error(401, "Unauthorized")
                return

            if self.path == "/health":
                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"status": "ok"}')
            elif self.path == "/tools":
                self.send_response(200)
                self.send_header("Content-type", "application/json")
                self.end_headers()
                from .registry import get_registry
                registry = get_registry()
                tools = [{"name": t.name, "description": t.description} for t in registry.list_enabled()]
                self.wfile.write(json.dumps(tools).encode())
            else:
                self.send_error(404, "Not Found")

    print(f"Starting HTTP server on localhost:{port}")
    print("Endpoints: /health, /tools")
    if token:
        print("Token authentication enabled")

    with socketserver.TCPServer(("127.0.0.1", port), Handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down")
    return 0


def _cmd_tray(args: argparse.Namespace) -> int:
    """Start system tray application."""
    from .tray import run_tray

    return run_tray()


def _cmd_watchdog(args: argparse.Namespace) -> int:
    from .watchdogs import fire_event, list_watchdogs

    if args.watchdog_cmd == "list":
        for w in list_watchdogs():
            print(f"{'[on]' if w.enable else '[off]'} {w.id} event={w.event} cooldown={w.cooldown_sec}")
        return 0
    if args.watchdog_cmd == "fire":
        result = fire_event(args.event, force=bool(args.force))
        print(json.dumps(result, indent=2))
        return 0 if result.get("ok") else 1
    print("Usage: ncc ai watchdog list|fire EVENT", file=sys.stderr)
    return 1


def _cmd_probe_disk(args: argparse.Namespace) -> int:
    from .probes import run_disk_probe_and_maybe_escalate, run_disk_nix_probe

    if args.escalate or args.force:
        result = run_disk_probe_and_maybe_escalate(
            threshold_pct=float(args.threshold),
            escalate=True,
            force=bool(args.force),
            playbook=args.playbook,
        )
    else:
        probe = run_disk_nix_probe(threshold_pct=float(args.threshold))
        result = {"ok": probe.ok, "probe": probe.to_dict(), "escalated": False}
    print(json.dumps(result, indent=2))
    return 0 if result.get("ok", True) else 1


def _cmd_rollback(args: argparse.Namespace) -> int:
    settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
    runtime = ToolRuntime(settings)
    print(json.dumps({
        "backups": runtime.list_config_backups(int(args.limit)),
        "generations": runtime.list_boot_generations(int(args.limit)),
        "hint": "sudo nixos-rebuild switch --rollback",
    }, indent=2))
    return 0


def _cmd_export_latest(args: argparse.Namespace) -> int:
    from .export_transcript import export_latest

    path = export_latest(kind=args.kind)
    print(path)
    return 0


def _cmd_red_team(args: argparse.Namespace) -> int:
    from .red_team import run_red_team_checks

    settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
    runtime = ToolRuntime(settings, dry_run=True)
    report = run_red_team_checks(runtime)
    payload = report.to_dict() if hasattr(report, "to_dict") else report
    print(json.dumps(payload, indent=2))
    ok = payload.get("ok", True) if isinstance(payload, dict) else True
    return 0 if ok else 1


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="ncc ai",
        description="NCC AI Assistant - GUI chat, CLI, MCP tools, and agent mode",
    )
    sub = parser.add_subparsers(dest="command", required=False)

    sub.add_parser("gui", help="Graphical chat window (default)")
    sub.add_parser("chat", help="Terminal chat (legacy)")
    sub.add_parser("cli", help="Alias for terminal chat")
    sub.add_parser("mcp", help="Run MCP server on stdio")

    tool_p = sub.add_parser("tool", help="Invoke a single tool (debug/scripting)")
    tool_p.add_argument("name", help="Tool name")
    tool_p.add_argument("--args", default="{}", help="JSON object of tool arguments")

    tools_p = sub.add_parser("tools", help="List available tools")
    tools_p.add_argument("--json", action="store_true", help="Output as JSON")

    agent_p = sub.add_parser("agent", help="Agent mode commands")
    agent_sub = agent_p.add_subparsers(dest="agent_cmd")
    agent_run = agent_sub.add_parser("run", help="Run agent with a goal")
    agent_run.add_argument("--goal", "-g", help="Goal for the agent")
    agent_run.add_argument("--max-steps", "-s", type=int, help="Maximum steps")
    agent_run.add_argument("--dry-run", "-n", action="store_true", help="Dry run mode")
    agent_run.add_argument("--profile", "-p", help="Security profile")
    agent_run.add_argument("--playbook", help="Run from playbook")

    jobs_p = sub.add_parser("jobs", help="Job management")
    jobs_sub = jobs_p.add_subparsers(dest="jobs_cmd")
    jobs_list = jobs_sub.add_parser("list", help="List jobs")
    jobs_list.add_argument("--limit", type=int, default=20)
    jobs_list.add_argument("--json", action="store_true")
    jobs_show = jobs_sub.add_parser("show", help="Show job details")
    jobs_show.add_argument("job_id", help="Job ID")
    jobs_log = jobs_sub.add_parser("log", help="Show job event log")
    jobs_log.add_argument("job_id", help="Job ID")

    playbook_p = sub.add_parser("playbook", help="Playbook management")
    playbook_sub = playbook_p.add_subparsers(dest="playbook_cmd")
    playbook_list = playbook_sub.add_parser("list", help="List playbooks")
    playbook_list.add_argument("--json", action="store_true")
    playbook_run = playbook_sub.add_parser("run", help="Run a playbook")
    playbook_run.add_argument("name", help="Playbook name")
    playbook_run.add_argument("--dry-run", "-n", action="store_true")

    presence_p = sub.add_parser("presence", help="Presence management")
    presence_sub = presence_p.add_subparsers(dest="presence_cmd")
    presence_sub.add_parser("status", help="Show presence status")
    presence_pause = presence_sub.add_parser("pause", help="Pause agent")
    presence_pause.add_argument("--reason", "-r", help="Pause reason")
    presence_resume = presence_sub.add_parser("resume", help="Resume agent")
    presence_resume.add_argument("--reason", "-r", help="Resume reason")

    approve_p = sub.add_parser("approve", help="Handle pending approvals")
    approve_p.add_argument("action", choices=["list", "allow", "block"], help="Action")
    approve_p.add_argument("decision_id", nargs="?", help="Decision ID")

    knowledge_p = sub.add_parser("knowledge", help="Knowledge management")
    knowledge_sub = knowledge_p.add_subparsers(dest="knowledge_cmd")
    knowledge_sync = knowledge_sub.add_parser("sync", help="Sync knowledge overlay")
    knowledge_sync.add_argument("--note", help="Add a note to overlay")

    export_p = sub.add_parser("export", help="Export transcripts")
    export_sub = export_p.add_subparsers(dest="export_cmd")
    export_session = export_sub.add_parser("session", help="Export chat session")
    export_session.add_argument("session_id", help="Session ID")
    export_session.add_argument("--output", "-o", help="Output file path")
    export_session.add_argument("--no-redact", action="store_true")
    export_job = export_sub.add_parser("job", help="Export job transcript")
    export_job.add_argument("job_id", help="Job ID")
    export_job.add_argument("--output", "-o", help="Output file path")
    export_job.add_argument("--no-redact", action="store_true")
    export_latest = export_sub.add_parser("latest", help="Export latest session or job")
    export_latest.add_argument("--kind", choices=["session", "job"], default="session")

    eval_p = sub.add_parser("eval", help="Evaluation harness")
    eval_sub = eval_p.add_subparsers(dest="eval_cmd")
    eval_run = eval_sub.add_parser("run", help="Run evaluation cases")
    eval_run.add_argument("--cases", "-c", help="Path to cases JSON file")
    eval_run.add_argument("--output", "-o", help="Output report path")

    serve_p = sub.add_parser("serve-openapi", help="Start minimal HTTP server")
    serve_p.add_argument("--port", type=int, default=8765, help="Port number")
    serve_p.add_argument("--token", help="Bearer token for auth")

    sub.add_parser("tray", help="Start system tray daemon")

    watchdog_p = sub.add_parser("watchdog", help="Event-triggered agent watchdogs")
    watchdog_sub = watchdog_p.add_subparsers(dest="watchdog_cmd")
    watchdog_sub.add_parser("list", help="List watchdogs")
    watchdog_fire = watchdog_sub.add_parser("fire", help="Fire a watchdog event")
    watchdog_fire.add_argument("event", help="Event name")
    watchdog_fire.add_argument("--force", action="store_true")

    probe_p = sub.add_parser("probe", help="Tool-only probes (no LLM unless escalate)")
    probe_sub = probe_p.add_subparsers(dest="probe_cmd")
    probe_disk = probe_sub.add_parser("disk", help="Disk / Nix store usage probe")
    probe_disk.add_argument("--threshold", type=float, default=85.0)
    probe_disk.add_argument(
        "--escalate",
        action="store_true",
        help="Run GC advisor playbook when over threshold",
    )
    probe_disk.add_argument(
        "--force",
        action="store_true",
        help="Escalate even when under threshold",
    )
    probe_disk.add_argument(
        "--playbook",
        default="disk-nix-gc-advisor",
        help="Playbook used on escalation",
    )

    rollback_p = sub.add_parser("rollback", help="List backups and boot generations")
    rollback_p.add_argument("--limit", type=int, default=20)

    sub.add_parser("red-team", help="Run red-team guard checks")

    args = parser.parse_args(argv)
    command = args.command or "gui"

    if command == "tools":
        return _cmd_tools(args)

    if command == "mcp":
        from .mcp_server import run_mcp

        settings = with_cached_credentials(Settings.from_env(client_mode="mcp"))
        run_mcp(settings)
        return 0

    if command == "tool":
        return _cmd_tool(args)

    if command in ("chat", "cli"):
        settings = Settings.from_env(client_mode="chat")
        return run_chat(settings)

    if command == "agent":
        if args.agent_cmd == "run":
            return _cmd_agent_run(args)
        parser.print_help()
        return 1

    if command == "jobs":
        if args.jobs_cmd == "list":
            return _cmd_jobs_list(args)
        if args.jobs_cmd == "show":
            return _cmd_jobs_show(args)
        if args.jobs_cmd == "log":
            return _cmd_jobs_log(args)
        parser.print_help()
        return 1

    if command == "playbook":
        if args.playbook_cmd == "list":
            return _cmd_playbook_list(args)
        if args.playbook_cmd == "run":
            return _cmd_playbook_run(args)
        parser.print_help()
        return 1

    if command == "presence":
        if args.presence_cmd == "status":
            return _cmd_presence_status(args)
        if args.presence_cmd == "pause":
            return _cmd_presence_pause(args)
        if args.presence_cmd == "resume":
            return _cmd_presence_resume(args)
        parser.print_help()
        return 1

    if command == "approve":
        return _cmd_approve(args)

    if command == "knowledge":
        if args.knowledge_cmd == "sync":
            return _cmd_knowledge_sync(args)
        parser.print_help()
        return 1

    if command == "export":
        if args.export_cmd == "session":
            return _cmd_export_session(args)
        if args.export_cmd == "job":
            return _cmd_export_job(args)
        if args.export_cmd == "latest":
            return _cmd_export_latest(args)
        parser.print_help()
        return 1

    if command == "eval":
        if args.eval_cmd == "run":
            return _cmd_eval_run(args)
        parser.print_help()
        return 1

    if command == "serve-openapi":
        return _cmd_serve_openapi(args)

    if command == "tray":
        return _cmd_tray(args)

    if command == "watchdog":
        return _cmd_watchdog(args)

    if command == "probe":
        if args.probe_cmd == "disk":
            return _cmd_probe_disk(args)
        print("Usage: ncc ai probe disk [--threshold 85] [--escalate]", file=sys.stderr)
        return 1

    if command == "rollback":
        return _cmd_rollback(args)

    if command == "red-team":
        return _cmd_red_team(args)

    from .gui import run_gui
    return run_gui(Settings.from_env(client_mode="chat"))


if __name__ == "__main__":
    raise SystemExit(main())
