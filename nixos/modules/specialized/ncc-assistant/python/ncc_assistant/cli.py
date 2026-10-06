"""CLI entry: ncc-assistant [gui|chat|mcp|agent|jobs|playbook|presence|approve|knowledge|export|eval|tools|secrets|workspaces|templates|workflows|focus|workflow|serve-openapi|tray]."""

from __future__ import annotations

import argparse
import json
import sys
from getpass import getpass
from pathlib import Path

from .auth import with_cached_credentials
from .chat import run_chat
from .cli_print import print_err, print_info, print_ok
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
        print_err(f"Invalid --args JSON: {exc}")
        return 2
    result = runtime.call(args.name, payload)
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0 if result.get("ok", True) else 1


def _cmd_agent_run(args: argparse.Namespace) -> int:
    """Run agent with a goal."""
    from .agent import run_agent
    from .capacity import CapacityError, capacity_slot
    from .harness import get_harness, looks_like_coding_goal, resolve_harness_name

    settings = with_cached_credentials(Settings.from_env(client_mode="chat"))

    playbook_goal = None
    if args.playbook:
        from .playbooks import get_playbook
        pb = get_playbook(args.playbook)
        if not pb:
            print_err(f"Playbook not found: {args.playbook}")
            return 1
        playbook_goal = pb.goal
        if not args.profile and pb.profile:
            args.profile = pb.profile
        if pb.dry_run:
            args.dry_run = True

    goal = args.goal or playbook_goal
    if not goal:
        print_err("--goal or --playbook required")
        return 1

    max_steps = args.max_steps or settings.agent_max_steps
    force = getattr(args, "harness", None)
    tags = ["coding"] if looks_like_coding_goal(goal) else []
    hname = resolve_harness_name(tags=tags, force=force)

    verbose = bool(getattr(args, "verbose", False))
    print_info(f"Starting agent with goal: {goal}")
    print_info(
        f"Harness: {hname}, Max steps: {max_steps}, "
        f"Dry run: {args.dry_run}, Profile: {args.profile or 'default'}"
    )
    print_info("---")

    try:
        with capacity_slot(f"agent:{hname}"):
            if hname != "native":
                events = get_harness(hname).send(goal)
            else:
                events = run_agent(
                    goal,
                    settings,
                    max_steps=max_steps,
                    dry_run=args.dry_run,
                    profile=args.profile,
                    playbook=args.playbook,
                )

            thinking_open = False
            for event in events:
                kind = event.get("kind")
                if kind == "job_started":
                    print_info(f"Job started: {event.get('job_id')}")
                elif kind == "step":
                    print_info(f"Step {event.get('step')}/{event.get('max_steps')}")
                elif kind == "thinking_delta":
                    if verbose:
                        print_info(f"thinking: {event.get('text', '')[:200]}")
                    elif not thinking_open:
                        print_info("Thinking…")
                        thinking_open = True
                elif kind == "assistant":
                    thinking_open = False
                    print_info(f"Assistant: {event.get('text', '')[:500]}")
                elif kind == "assistant_delta":
                    thinking_open = False
                elif kind == "tool":
                    thinking_open = False
                    name = event.get("name")
                    if verbose:
                        print_info(f"Tool: {name}({json.dumps(event.get('args', {}))})")
                    else:
                        print_info(f"▸ {name}")
                elif kind == "tool_result":
                    text = event.get("text", "")
                    if verbose:
                        print_info(
                            f"Result: {text[:300]}{'...' if len(text) > 300 else ''}"
                        )
                    else:
                        print_info(
                            f"  ↳ {text[:120]}{'…' if len(text) > 120 else ''}"
                        )
                elif kind == "status":
                    if verbose:
                        print_info(
                            f"status: {event.get('text') or event.get('phase') or ''}"
                        )
                elif kind == "run_spawn":
                    print_info(
                        f"▸ Subagent: {event.get('title') or event.get('name') or 'child'}"
                    )
                elif kind == "agent_finish":
                    print_ok(f"Agent finished: {event.get('summary')}")
                    print_info(f"Success: {event.get('success')}")
                elif kind == "error":
                    print_err(event.get("text", ""))
                elif kind == "job_finished":
                    print_ok(
                        f"Job {event.get('job_id')} completed "
                        f"(success={event.get('success')})"
                    )
                elif kind == "job_failed":
                    print_err(
                        f"Job {event.get('job_id')} failed: {event.get('error')}"
                    )
                elif kind == "job_cancelled":
                    print_info(f"Job {event.get('job_id')} cancelled")
    except CapacityError as exc:
        print_err(str(exc))
        return 1

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
        print_err(f"Job not found: {args.job_id}")
        return 1
    print(json.dumps(job.to_dict(), indent=2))
    result = store.get_result(args.job_id)
    if result:
        print_info("Result:")
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
        print_err(f"Playbook not found: {args.name}")
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
    print_ok(f"Agent paused: {presence.state}")
    return 0


def _cmd_presence_resume(args: argparse.Namespace) -> int:
    """Resume agent."""
    from .presence import resume
    presence = resume(reason=args.reason)
    print_ok(f"Agent resumed: {presence.state}")
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
        print_err("decision_id required for allow/block")
        return 1

    if args.action == "allow":
        result = service.allow(args.decision_id)
    else:
        result = service.block(args.decision_id)

    if result:
        print_ok(f"Decision {args.decision_id}: {result.result}")
    else:
        print_err(f"Decision not found: {args.decision_id}")
        return 1
    return 0


def _cmd_knowledge_sync(args: argparse.Namespace) -> int:
    """Sync knowledge overlay."""
    from .paths import knowledge_overlay_dir

    overlay = knowledge_overlay_dir()
    print_info(f"Knowledge overlay directory: {overlay}")

    if args.note:
        note_file = overlay / "user-notes.md"
        with note_file.open("a", encoding="utf-8") as f:
            f.write(f"\n- {args.note}\n")
        print_ok(f"Added note to {note_file}")

    return 0


def _cmd_export_session(args: argparse.Namespace) -> int:
    """Export session to markdown."""
    from .export_transcript import export_session_markdown, export_to_file

    content = export_session_markdown(args.session_id, redact=not args.no_redact)

    if args.output:
        path = export_to_file(content, args.output)
        print_ok(f"Exported to {path}")
    else:
        print(content)
    return 0


def _cmd_export_job(args: argparse.Namespace) -> int:
    """Export job to markdown."""
    from .export_transcript import export_job_markdown, export_to_file

    content = export_job_markdown(args.job_id, redact=not args.no_redact)

    if args.output:
        path = export_to_file(content, args.output)
        print_ok(f"Exported to {path}")
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
        print_err("No evaluation cases found")
        return 1

    print_info(f"Running {len(cases)} evaluation cases...")

    def on_result(result):
        status = "PASS" if result.passed else "FAIL"
        print_info(f"[{status}] {result.case_name} ({result.duration_ms:.0f}ms)")
        if not result.passed:
            for detail in result.details:
                print(f"       {detail}")
            if result.error:
                print_err(result.error)

    report = harness.run_all(cases, on_result=on_result)

    print_ok(f"Results: {report.passed}/{report.total} passed, {report.failed} failed")

    if args.output:
        Path(args.output).write_text(json.dumps(report.to_dict(), indent=2), encoding="utf-8")
        print_ok(f"Report written to {args.output}")

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

    print_info(f"Starting HTTP server on localhost:{port}")
    print_info("Endpoints: /health, /tools")
    if token:
        print_info("Token authentication enabled")

    with socketserver.TCPServer(("127.0.0.1", port), Handler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print_info("Shutting down")
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
    print_err("Usage: ncc ai watchdog list|fire EVENT")
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


def _cmd_secrets(args: argparse.Namespace) -> int:
    from .secrets import delete_secret, list_secrets, set_secret

    cmd = args.secrets_cmd
    if cmd == "list":
        items = [s.to_public_dict() for s in list_secrets()]
        if args.json:
            print(json.dumps(items, indent=2))
        else:
            if not items:
                print_info("(no secrets)")
            for s in items:
                print(f"{s['name']:24} {s.get('label') or ''}  updated={s.get('updated') or '-'}")
        return 0
    if cmd == "set":
        value = args.value
        if not value:
            if not sys.stdin.isatty():
                print_err("Pass --value or run on a TTY to prompt.")
                return 2
            value = getpass(f"Value for secret {args.name}: ").strip()
        try:
            meta = set_secret(args.name, value, label=args.label)
        except ValueError as exc:
            print_err(str(exc))
            return 2
        print_ok(f"Saved secret {meta.name} (value not printed)")
        return 0
    if cmd == "delete":
        if delete_secret(args.name):
            print_ok(f"Deleted secret {args.name}")
            return 0
        print_err(f"Secret not found: {args.name}")
        return 1
    print_err("Usage: ncc ai secrets list|set|delete")
    return 1


def _cmd_workspaces(args: argparse.Namespace) -> int:
    from .workspaces import delete_workspace, list_workspaces, upsert_workspace

    cmd = args.workspaces_cmd
    if cmd == "list":
        items = [w.to_dict() for w in list_workspaces()]
        if args.json:
            print(json.dumps(items, indent=2))
        else:
            if not items:
                print_info("(no workspaces)")
            for w in items:
                gh = f"  github:{w['github']}" if w.get("github") else ""
                print(f"{w['id']:16} {w['path']}{gh}")
        return 0
    if cmd == "add":
        try:
            ws = upsert_workspace(
                args.id,
                args.path,
                label=args.label,
                github=args.github,
            )
        except ValueError as exc:
            print_err(str(exc))
            return 2
        print_ok(f"Workspace {ws.id} → {ws.path}")
        return 0
    if cmd == "delete":
        if delete_workspace(args.id):
            print_ok(f"Deleted workspace {args.id}")
            return 0
        print_err(f"Workspace not found: {args.id}")
        return 1
    print_err("Usage: ncc ai workspaces list|add|delete")
    return 1


def _cmd_templates(args: argparse.Namespace) -> int:
    from .agent_templates import (
        get_agent_template,
        instantiate,
        list_agent_templates,
        list_instances,
        run_instance,
        template_badges,
    )

    cmd = args.templates_cmd
    if cmd == "list":
        rows = []
        for t in list_agent_templates():
            badges = [b["label"] for b in template_badges(t)]
            rows.append(
                {
                    "id": t.id,
                    "title": t.title,
                    "category": t.category,
                    "tier": t.tier,
                    "badges": badges,
                }
            )
        if args.json:
            print(json.dumps(rows, indent=2))
        else:
            for r in rows:
                badge = f"  [{', '.join(r['badges'])}]" if r["badges"] else ""
                print(f"{r['id']:28} {r['tier']:7} {r['title']}{badge}")
        return 0
    if cmd == "show":
        t = get_agent_template(args.id)
        if not t:
            print_err(f"Unknown template: {args.id}")
            return 1
        payload = t.to_dict()
        payload["badges"] = template_badges(t)
        print(json.dumps(payload, indent=2))
        return 0
    if cmd == "instantiate":
        try:
            params = json.loads(Path(args.from_file).read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            print_err(f"Cannot read params: {exc}")
            return 2
        if not isinstance(params, dict):
            print_err("Params file must be a JSON object")
            return 2
        result = instantiate(
            args.id,
            params,
            instance_id=args.instance_id,
            title=args.title,
            enable_schedule=bool(args.schedule),
        )
        print(json.dumps({k: v for k, v in result.items() if k != "goal"} | {"goal_preview": (result.get("goal") or "")[:400]}, indent=2))
        return 0 if result.get("ok") else 1
    if cmd == "run":
        from .capacity import CapacityError

        try:
            for event in run_instance(args.instance_id, dry_run=bool(args.dry_run) or None):
                kind = event.get("kind")
                if kind in ("job_started", "step", "agent_finish", "error", "budget"):
                    print_info(f"{kind}: {json.dumps({k: v for k, v in event.items() if k != 'kind'}, default=str)[:300]}")
        except CapacityError as exc:
            print_err(str(exc))
            return 1
        except ValueError as exc:
            print_err(str(exc))
            return 1
        return 0
    if cmd == "instances":
        items = [i.to_dict() for i in list_instances()]
        if args.json:
            print(json.dumps(items, indent=2))
        else:
            if not items:
                print_info("(no instances)")
            for i in items:
                print(f"{i['id']:32} {i['templateId']:24} {i['title']}")
        return 0
    print_err("Usage: ncc ai templates list|show|instantiate|run|instances")
    return 1


def _cmd_workflows(args: argparse.Namespace) -> int:
    from .workflows import (
        add_roadmap_item,
        add_task,
        complete_task,
        list_roadmap,
        list_tasks,
        load_daily,
        refresh_github_digest,
        update_roadmap_item,
        update_task,
    )

    cmd = args.workflows_cmd
    if cmd == "show":
        print(json.dumps(load_daily(), indent=2))
        return 0
    if cmd == "refresh":
        data = refresh_github_digest()
        print_ok(
            f"Digest updated: {len(data.get('issues') or [])} issues, "
            f"{len(data.get('pullRequests') or [])} PRs"
        )
        return 0
    if cmd == "tasks":
        sub = args.workflows_tasks_cmd
        if sub == "list":
            items = list_tasks()
            if getattr(args, "json", False):
                print(json.dumps(items, indent=2))
            else:
                for t in items:
                    print(
                        f"{t.get('id')}  [{t.get('priority')}] {t.get('status'):5}  "
                        f"{t.get('title')}"
                    )
            return 0
        if sub == "add":
            t = add_task(
                args.title,
                priority=args.priority or "p1",
                status=args.status or "todo",
            )
            print_ok(f"Task {t['id']}: {t['title']}")
            return 0
        if sub == "complete":
            t = complete_task(args.id)
            if not t:
                print_err(f"Task not found: {args.id}")
                return 1
            print_ok(f"Completed {t['id']}")
            return 0
        if sub == "update":
            fields: dict = {}
            if args.title:
                fields["title"] = args.title
            if args.status:
                fields["status"] = args.status
            if args.priority:
                fields["priority"] = args.priority
            t = update_task(args.id, **fields)
            if not t:
                print_err(f"Task not found: {args.id}")
                return 1
            print_ok(f"Updated {t['id']}")
            return 0
        print_err("Usage: ncc ai workflows tasks list|add|complete|update")
        return 1
    if cmd == "roadmap":
        sub = args.workflows_roadmap_cmd
        if sub == "list":
            items = list_roadmap()
            if getattr(args, "json", False):
                print(json.dumps(items, indent=2))
            else:
                for r in items:
                    print(f"{r.get('id')}  [{r.get('horizon')}] {r.get('title')}")
            return 0
        if sub == "add":
            r = add_roadmap_item(args.title, horizon=args.horizon or "now")
            print_ok(f"Roadmap {r['id']}: {r['title']}")
            return 0
        if sub == "update":
            fields = {}
            if args.title:
                fields["title"] = args.title
            if args.horizon:
                fields["horizon"] = args.horizon
            r = update_roadmap_item(args.id, **fields)
            if not r:
                print_err(f"Roadmap item not found: {args.id}")
                return 1
            print_ok(f"Updated {r['id']}")
            return 0
        print_err("Usage: ncc ai workflows roadmap list|add|update")
        return 1
    print_err("Usage: ncc ai workflows show|refresh|tasks|roadmap")
    return 1


def _cmd_focus(args: argparse.Namespace) -> int:
    from .focus import snooze, status, tick

    cmd = args.focus_cmd
    if cmd == "status":
        print(json.dumps(status(), indent=2))
        return 0
    if cmd == "tick":
        print(json.dumps(tick(), indent=2))
        return 0
    if cmd == "snooze":
        mins = int(getattr(args, "minutes", 30) or 30)
        print(json.dumps(snooze(mins), indent=2))
        print_ok(f"Snoozed {mins} min")
        return 0
    print_err("Usage: ncc ai focus status|tick|snooze")
    return 1


def _cmd_workflow(args: argparse.Namespace) -> int:
    from .workflow_execute import (
        bump_version,
        commit_all,
        ensure_branch,
        execute_status,
        merge_pull_request,
        open_pull_request,
        resume_status,
        task_finish,
        task_start,
        validate_workspace,
    )
    from .workspace_lifecycle import (
        fleet_lifecycle,
        format_fleet_text,
        format_lifecycle_text,
        lifecycle_report,
    )
    from .workspace_workflow import (
        audit_workspace,
        dump_audit_json,
        format_audit_text,
        next_open_task,
        plan_from_audit,
        task_gap_id,
        workflow_status,
    )

    cmd = args.workflow_cmd
    wid = getattr(args, "workspace", None) or None
    try:
        if cmd == "audit":
            report = audit_workspace(wid)
            if getattr(args, "json", False):
                print(dump_audit_json(report))
            else:
                print(format_audit_text(report))
            return 0
        if cmd == "lifecycle":
            if getattr(args, "all", False):
                fleet = fleet_lifecycle(
                    active_days=int(getattr(args, "active_days", 14) or 14),
                    once_days=int(getattr(args, "once_days", 90) or 90),
                    archive_days=int(getattr(args, "archive_days", 180) or 180),
                )
                if getattr(args, "json", False):
                    print(json.dumps(fleet, indent=2, ensure_ascii=False))
                else:
                    print(format_fleet_text(fleet))
                return 0
            rep = lifecycle_report(
                wid,
                active_days=int(getattr(args, "active_days", 14) or 14),
                once_days=int(getattr(args, "once_days", 90) or 90),
                archive_days=int(getattr(args, "archive_days", 180) or 180),
            )
            if getattr(args, "json", False):
                print(json.dumps(rep, indent=2, ensure_ascii=False))
            else:
                print(format_lifecycle_text(rep))
            return 0
        if cmd == "fleet":
            fleet = fleet_lifecycle(
                active_days=int(getattr(args, "active_days", 14) or 14),
                once_days=int(getattr(args, "once_days", 90) or 90),
                archive_days=int(getattr(args, "archive_days", 180) or 180),
            )
            if getattr(args, "json", False):
                print(json.dumps(fleet, indent=2, ensure_ascii=False))
            else:
                print(format_fleet_text(fleet))
            return 0
        if cmd == "plan":
            result = plan_from_audit(
                wid, create_roadmap=not getattr(args, "no_roadmap", False)
            )
            if getattr(args, "json", False):
                print(json.dumps(result, indent=2, ensure_ascii=False))
            else:
                print_ok(
                    f"Workspace {result['workspace_id']}: "
                    f"+{len(result.get('created_tasks') or [])} tasks, "
                    f"skipped {len(result.get('skipped_gaps') or [])} gaps"
                )
                for t in result.get("created_tasks") or []:
                    print(
                        f"  {t.get('id')}  [{t.get('priority')}] {t.get('title')}"
                    )
            return 0
        if cmd == "status":
            st = workflow_status(wid)
            ex = execute_status(wid)
            payload = {**st, "execute": ex}
            if getattr(args, "json", False):
                print(json.dumps(payload, indent=2, ensure_ascii=False))
            else:
                print(
                    f"{st['workspace_id']}  gaps={st['missing_count']}  "
                    f"open_tasks={st['open_tasks']}  "
                    f"branch={ex.get('branch')}  dirty={ex.get('dirty')}"
                )
                if st.get("missing"):
                    print("  missing: " + ", ".join(st["missing"]))
                nxt = st.get("next")
                if nxt:
                    print(
                        f"  next: [{nxt.get('priority')}] {nxt.get('gap')}  "
                        f"{nxt.get('title')}"
                    )
                for t in st.get("tasks") or []:
                    print(
                        f"  [{t.get('priority')}] {t.get('status')}  "
                        f"{t.get('gap') or '—'}  {t.get('title')}"
                    )
                if ex.get("pr_url"):
                    print(f"  pr: {ex['pr_url']}")
            return 0
        if cmd == "next":
            nxt = next_open_task(wid)
            payload = {
                "ok": bool(nxt),
                "workspace_id": resolve_wid(wid),
                "task": (
                    {
                        "id": nxt.get("id"),
                        "title": nxt.get("title"),
                        "status": nxt.get("status"),
                        "priority": nxt.get("priority"),
                        "gap": task_gap_id(nxt),
                        "links": list(nxt.get("links") or []),
                    }
                    if nxt
                    else None
                ),
            }
            if getattr(args, "json", False):
                print(json.dumps(payload, indent=2, ensure_ascii=False))
            elif nxt:
                print_ok(
                    f"next [{nxt.get('priority')}] {task_gap_id(nxt)}  "
                    f"{nxt.get('id')}  {nxt.get('title')}"
                )
            else:
                print_info("No open p0/p1 tasks")
            return 0
        if cmd == "resume":
            result = resume_status(wid)
            if getattr(args, "json", False):
                print(json.dumps(result, indent=2, ensure_ascii=False))
            else:
                print_ok(str(result.get("hint") or "resume"))
                cur = result.get("current_task")
                if cur:
                    print(
                        f"  current: {cur.get('id')} [{cur.get('gap')}] "
                        f"branch={cur.get('branch')}"
                    )
                nxt = result.get("next")
                if nxt:
                    print(
                        f"  next: {nxt.get('id')} [{nxt.get('gap')}] "
                        f"{nxt.get('title')}"
                    )
            return 0
        if cmd == "task-start":
            result = task_start(
                wid,
                task_id=getattr(args, "task", None) or None,
                allow_dirty=bool(getattr(args, "allow_dirty", False)),
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0 if result.get("ok") else 1
        if cmd == "task-finish":
            result = task_finish(
                wid,
                task_id=getattr(args, "task", None) or None,
                message=getattr(args, "message", "") or "",
                title=getattr(args, "title", "") or "",
                body=getattr(args, "body", "") or "",
                skip_rebase=bool(getattr(args, "skip_rebase", False)),
                draft=bool(getattr(args, "draft", False)),
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0 if result.get("ok") else 1
        if cmd == "branch":
            result = ensure_branch(
                wid,
                branch=getattr(args, "name", None) or None,
                prefix=getattr(args, "prefix", None) or "work",
                task_id=getattr(args, "task", None) or None,
                from_default=bool(getattr(args, "from_default", False)),
                allow_dirty=bool(getattr(args, "allow_dirty", False)),
            )
            if getattr(args, "json", False):
                print(json.dumps(result, indent=2, ensure_ascii=False))
            elif result.get("ok"):
                print_ok(
                    f"branch {result.get('branch')} "
                    f"({'existing' if result.get('already') else 'created'})"
                )
            else:
                print_err(str(result.get("error") or "branch failed"))
            return 0 if result.get("ok") else 1
        if cmd == "validate":
            result = validate_workspace(wid)
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0 if result.get("ok") else 1
        if cmd == "commit":
            result = commit_all(wid, message=getattr(args, "message", "") or "")
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0 if result.get("ok") else 1
        if cmd == "pr":
            result = open_pull_request(
                wid,
                title=getattr(args, "title", "") or "ncc workflow updates",
                body=getattr(args, "body", "") or "",
                draft=bool(getattr(args, "draft", False)),
                require_clean_validate=bool(
                    getattr(args, "require_validate", False)
                ),
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0 if result.get("ok") else 1
        if cmd == "merge":
            result = merge_pull_request(
                wid,
                pr=getattr(args, "pr", None) or None,
                confirm=getattr(args, "confirm", "") or "",
                strategy=getattr(args, "strategy", None) or "squash",
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0 if result.get("ok") else 1
        if cmd == "bump":
            result = bump_version(
                wid,
                confirm=getattr(args, "confirm", "") or "",
                part=getattr(args, "part", None) or "patch",
            )
            print(json.dumps(result, indent=2, ensure_ascii=False))
            return 0 if result.get("ok") else 1
    except (ValueError, RuntimeError) as exc:
        print_err(str(exc))
        return 1
    print_err(
        "Usage: ncc ai workflow audit|lifecycle|fleet|plan|status|next|resume|"
        "task-start|task-finish|branch|validate|commit|pr|merge|bump"
    )
    return 1


def resolve_wid(workspace_id: str | None) -> str:
    from .workspace_workflow import resolve_workspace_id

    return resolve_workspace_id(workspace_id)


def _cmd_mcp_install(args: argparse.Namespace) -> int:
    from .marketplace import install_template

    overrides: dict[str, str] = {}
    for item in args.secret or []:
        if "=" not in item:
            print_err(f"Expected ENV=secret_name, got: {item}")
            return 2
        env_key, secret_name = item.split("=", 1)
        overrides[env_key.strip()] = secret_name.strip()
    result = install_template(
        args.name,
        workspace_id=args.workspace,
        secret_overrides=overrides or None,
        install_as=args.install_as,
    )
    # Never dump secret values
    print(json.dumps(result, indent=2))
    return 0 if result.get("ok") else 1


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
    agent_run.add_argument(
        "--harness",
        choices=["native", "qwen", "dsh"],
        help="Force agent harness (default: settings / coding auto)",
    )
    agent_run.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Full thinking/tool dumps (default: compact one-liners)",
    )

    harness_p = sub.add_parser("harness", help="Coding harness backends (native/qwen/dsh)")
    harness_sub = harness_p.add_subparsers(dest="harness_cmd")
    harness_sub.add_parser("status", help="Probe available harnesses")
    harness_probe = harness_sub.add_parser("probe", help="Probe one harness")
    harness_probe.add_argument("name", choices=["native", "qwen", "dsh"])

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
    sub.add_parser(
        "companion",
        help="Desktop companion (avatar + mini chat, always-on-top)",
    )

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

    secrets_p = sub.add_parser("secrets", help="Named agent secrets (not LLM provider keys)")
    secrets_sub = secrets_p.add_subparsers(dest="secrets_cmd")
    secrets_list = secrets_sub.add_parser("list", help="List secret names (no values)")
    secrets_list.add_argument("--json", action="store_true")
    secrets_set = secrets_sub.add_parser("set", help="Create or rotate a secret")
    secrets_set.add_argument("name", help="Secret name (e.g. github_token)")
    secrets_set.add_argument("--label", help="Display label")
    secrets_set.add_argument(
        "--value",
        help="Secret value (omit to prompt; prefer prompt on TTY)",
    )
    secrets_del = secrets_sub.add_parser("delete", help="Delete a secret")
    secrets_del.add_argument("name", help="Secret name")

    ws_p = sub.add_parser("workspaces", help="Local git workspace registry")
    ws_sub = ws_p.add_subparsers(dest="workspaces_cmd")
    ws_list = ws_sub.add_parser("list", help="List workspaces")
    ws_list.add_argument("--json", action="store_true")
    ws_add = ws_sub.add_parser("add", help="Add or update a workspace")
    ws_add.add_argument("--id", required=True, help="Workspace id")
    ws_add.add_argument("--path", required=True, help="Local directory path")
    ws_add.add_argument("--label", help="Display label")
    ws_add.add_argument("--github", help="owner/repo")
    ws_del = ws_sub.add_parser("delete", help="Remove a workspace")
    ws_del.add_argument("id", help="Workspace id")

    tmpl_p = sub.add_parser("templates", help="Agent workflow templates")
    tmpl_sub = tmpl_p.add_subparsers(dest="templates_cmd")
    tmpl_list = tmpl_sub.add_parser("list", help="List agent templates")
    tmpl_list.add_argument("--json", action="store_true")
    tmpl_show = tmpl_sub.add_parser("show", help="Show one template")
    tmpl_show.add_argument("id", help="Template id")
    tmpl_inst = tmpl_sub.add_parser("instantiate", help="Create instance from params JSON")
    tmpl_inst.add_argument("id", help="Template id")
    tmpl_inst.add_argument("--from", dest="from_file", required=True, help="Params JSON file")
    tmpl_inst.add_argument("--instance-id", help="Instance id")
    tmpl_inst.add_argument("--title", help="Instance title")
    tmpl_inst.add_argument("--schedule", action="store_true", help="Also save a user schedule")
    tmpl_run = tmpl_sub.add_parser("run", help="Run a saved instance")
    tmpl_run.add_argument("instance_id", help="Instance id")
    tmpl_run.add_argument("--dry-run", "-n", action="store_true")
    tmpl_instances = tmpl_sub.add_parser("instances", help="List saved instances")
    tmpl_instances.add_argument("--json", action="store_true")

    wf_p = sub.add_parser("workflows", help="Daily workflows / tasks / roadmap")
    wf_sub = wf_p.add_subparsers(dest="workflows_cmd")
    wf_sub.add_parser("show", help="Show daily.json digest")
    wf_sub.add_parser("refresh", help="Refresh GitHub Issues/PRs into daily.json")
    wf_tasks = wf_sub.add_parser("tasks", help="Local task CRUD")
    wf_tasks_sub = wf_tasks.add_subparsers(dest="workflows_tasks_cmd")
    wf_tl = wf_tasks_sub.add_parser("list", help="List tasks")
    wf_tl.add_argument("--json", action="store_true")
    wf_ta = wf_tasks_sub.add_parser("add", help="Add a task")
    wf_ta.add_argument("title")
    wf_ta.add_argument("--priority", choices=["p0", "p1", "p2"], default="p1")
    wf_ta.add_argument("--status", choices=["todo", "doing", "done"], default="todo")
    wf_tc = wf_tasks_sub.add_parser("complete", help="Mark task done")
    wf_tc.add_argument("id")
    wf_tu = wf_tasks_sub.add_parser("update", help="Update a task")
    wf_tu.add_argument("id")
    wf_tu.add_argument("--title")
    wf_tu.add_argument("--priority", choices=["p0", "p1", "p2"])
    wf_tu.add_argument("--status", choices=["todo", "doing", "done"])
    wf_rm = wf_sub.add_parser("roadmap", help="Roadmap item CRUD")
    wf_rm_sub = wf_rm.add_subparsers(dest="workflows_roadmap_cmd")
    wf_rl = wf_rm_sub.add_parser("list", help="List roadmap items")
    wf_rl.add_argument("--json", action="store_true")
    wf_ra = wf_rm_sub.add_parser("add", help="Add roadmap item")
    wf_ra.add_argument("title")
    wf_ra.add_argument("--horizon", choices=["now", "next", "later"], default="now")
    wf_ru = wf_rm_sub.add_parser("update", help="Update roadmap item")
    wf_ru.add_argument("id")
    wf_ru.add_argument("--title")
    wf_ru.add_argument("--horizon", choices=["now", "next", "later"])

    focus_p = sub.add_parser("focus", help="Doomscroll / focus watchdog")
    focus_sub = focus_p.add_subparsers(dest="focus_cmd")
    focus_sub.add_parser("status", help="Show focus streak / settings")
    focus_sub.add_parser("tick", help="Run one probe tick")
    focus_snooze = focus_sub.add_parser("snooze", help="Snooze interventions")
    focus_snooze.add_argument(
        "--minutes", "-m", type=int, default=30, help="Snooze minutes (default 30)"
    )

    workflow_p = sub.add_parser(
        "workflow", help="Workspace workflow: audit gaps / plan Daily tasks"
    )
    workflow_sub = workflow_p.add_subparsers(dest="workflow_cmd")
    st_audit = workflow_sub.add_parser("audit", help="Scan workspace for structural gaps")
    st_audit.add_argument("--workspace", "-w", help="Workspace id (default: active)")
    st_audit.add_argument("--json", action="store_true")
    st_life = workflow_sub.add_parser(
        "lifecycle",
        help="Classify workspace: active / once / later / archive-candidate",
    )
    st_life.add_argument("--workspace", "-w")
    st_life.add_argument(
        "--all",
        action="store_true",
        help="Scan all registered workspaces (same as fleet)",
    )
    st_life.add_argument("--json", action="store_true")
    st_life.add_argument("--active-days", type=int, default=14)
    st_life.add_argument("--once-days", type=int, default=90)
    st_life.add_argument("--archive-days", type=int, default=180)
    st_fleet = workflow_sub.add_parser(
        "fleet",
        help="Lifecycle for all workspaces + archive candidates",
    )
    st_fleet.add_argument("--json", action="store_true")
    st_fleet.add_argument("--active-days", type=int, default=14)
    st_fleet.add_argument("--once-days", type=int, default=90)
    st_fleet.add_argument("--archive-days", type=int, default=180)
    st_plan = workflow_sub.add_parser(
        "plan", help="Create Daily tasks from missing gaps"
    )
    st_plan.add_argument("--workspace", "-w", help="Workspace id (default: active)")
    st_plan.add_argument("--json", action="store_true")
    st_plan.add_argument(
        "--no-roadmap",
        action="store_true",
        help="Do not add a roadmap chip for the gap set",
    )
    st_status = workflow_sub.add_parser("status", help="Gaps + open tasks + execute status")
    st_status.add_argument("--workspace", "-w", help="Workspace id (default: active)")
    st_status.add_argument("--json", action="store_true")
    st_next = workflow_sub.add_parser("next", help="Show next open p0/p1 task")
    st_next.add_argument("--workspace", "-w")
    st_next.add_argument("--json", action="store_true")
    st_resume = workflow_sub.add_parser(
        "resume", help="Show checkpoint + what to run next"
    )
    st_resume.add_argument("--workspace", "-w")
    st_resume.add_argument("--json", action="store_true")
    st_tstart = workflow_sub.add_parser(
        "task-start",
        help="Mark task doing + create per-task branch from default",
    )
    st_tstart.add_argument("--workspace", "-w")
    st_tstart.add_argument("--task", "-t", help="Task id (default: resume/next)")
    st_tstart.add_argument(
        "--allow-dirty",
        action="store_true",
        help="Allow starting with a dirty worktree",
    )
    st_tfin = workflow_sub.add_parser(
        "task-finish",
        help="Validate → commit → rebase → PR → mark done (hard validate gate)",
    )
    st_tfin.add_argument("--workspace", "-w")
    st_tfin.add_argument("--task", "-t", help="Task id (default: current)")
    st_tfin.add_argument("-m", "--message", default="", help="Commit message")
    st_tfin.add_argument("--title", default="", help="PR title")
    st_tfin.add_argument("--body", default="", help="PR body")
    st_tfin.add_argument("--draft", action="store_true")
    st_tfin.add_argument(
        "--skip-rebase",
        action="store_true",
        help="Skip rebase onto default before push",
    )
    st_branch = workflow_sub.add_parser("branch", help="Create/switch ncc/workflow-* branch")
    st_branch.add_argument("--workspace", "-w")
    st_branch.add_argument("--name", help="Full branch name (must start with ncc/workflow-)")
    st_branch.add_argument("--prefix", default="work", help="Slug prefix for auto name")
    st_branch.add_argument("--task", help="Task id fragment for branch name")
    st_branch.add_argument(
        "--from-default",
        action="store_true",
        help="Checkout default branch before creating",
    )
    st_branch.add_argument("--allow-dirty", action="store_true")
    st_branch.add_argument("--json", action="store_true")
    st_val = workflow_sub.add_parser("validate", help="Run detected project validators")
    st_val.add_argument("--workspace", "-w")
    st_commit = workflow_sub.add_parser("commit", help="git add -A && commit")
    st_commit.add_argument("--workspace", "-w")
    st_commit.add_argument("-m", "--message", default="ncc workflow: workspace updates")
    st_pr = workflow_sub.add_parser("pr", help="Push branch + open GitHub PR (gh)")
    st_pr.add_argument("--workspace", "-w")
    st_pr.add_argument("--title", default="ncc workflow updates")
    st_pr.add_argument("--body", default="")
    st_pr.add_argument("--draft", action="store_true")
    st_pr.add_argument(
        "--require-validate",
        action="store_true",
        help="Refuse PR if project validators fail",
    )
    st_merge = workflow_sub.add_parser(
        "merge", help='Merge current PR (requires --confirm CONFIRM)'
    )
    st_merge.add_argument("--workspace", "-w")
    st_merge.add_argument("--pr", help="PR number or URL (default: current branch PR)")
    st_merge.add_argument(
        "--confirm",
        required=True,
        help='Must be the literal token CONFIRM',
    )
    st_merge.add_argument(
        "--strategy",
        choices=["squash", "merge", "rebase"],
        default="squash",
    )
    st_bump = workflow_sub.add_parser(
        "bump", help='Bump package.json version (requires --confirm CONFIRM)'
    )
    st_bump.add_argument("--workspace", "-w")
    st_bump.add_argument(
        "--confirm",
        required=True,
        help='Must be the literal token CONFIRM',
    )
    st_bump.add_argument(
        "--part", choices=["major", "minor", "patch"], default="patch"
    )

    mcp_p = sub.add_parser("mcp-install", help="Install an MCP marketplace template")
    mcp_p.add_argument("name", help="MCP template name (git, github, …)")
    mcp_p.add_argument("--workspace", help="Workspace id for {{workspace.path}}")
    mcp_p.add_argument(
        "--secret",
        action="append",
        default=[],
        help="ENV=secret_name (e.g. GITHUB_PERSONAL_ACCESS_TOKEN=github_token)",
    )
    mcp_p.add_argument("--as", dest="install_as", help="Install under a custom server name")

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

    if command == "companion":
        from .companion import run_companion

        return run_companion()

    if command == "harness":
        from .harness import available_harnesses, get_harness

        if args.harness_cmd == "probe":
            info = get_harness(args.name).probe()
            print_info(f"{info.name}: {'ok' if info.available else 'missing'} — {info.detail}")
            return 0 if info.available else 1
        # status (default)
        for info in available_harnesses():
            mark = "OK" if info.available else "--"
            print_info(f"[{mark}] {info.name:8}  {info.detail}")
        return 0

    if command == "watchdog":
        return _cmd_watchdog(args)

    if command == "probe":
        if args.probe_cmd == "disk":
            return _cmd_probe_disk(args)
        print_err("Usage: ncc ai probe disk [--threshold 85] [--escalate]")
        return 1

    if command == "rollback":
        return _cmd_rollback(args)

    if command == "red-team":
        return _cmd_red_team(args)

    if command == "secrets":
        return _cmd_secrets(args)

    if command == "workspaces":
        return _cmd_workspaces(args)

    if command == "templates":
        return _cmd_templates(args)

    if command == "workflows":
        return _cmd_workflows(args)

    if command == "focus":
        return _cmd_focus(args)

    if command == "workflow":
        return _cmd_workflow(args)

    if command == "mcp-install":
        return _cmd_mcp_install(args)

    from .gui import run_gui
    return run_gui(Settings.from_env(client_mode="chat"))


if __name__ == "__main__":
    raise SystemExit(main())
