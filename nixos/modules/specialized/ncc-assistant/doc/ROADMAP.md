# NCC AI Assistant — Roadmap

Status: **planning only** (not implemented unless a phase doc says otherwise).  
Usage of the current chat/MCP product: [USAGE.md](./USAGE.md).

## Goal

Extend `ncc-assistant` from interactive chat + built-in tools + MCP *server*
into a system that can:

1. Register **custom tools** and **MCP clients** (bring other servers into NCC).
2. Run an **agent** with a goal, budget, and the same tool layer as chat.
3. Schedule agent work via **systemd timers / cron-like** calendars.
4. Expose all of that in the **Qt GUI** (Tools, Agent, Jobs, Schedules).
5. Grow into playbooks, health/drift, notifications/presence, and quality gates.

## Non-negotiables

| Rule | Why |
|------|-----|
| One tool runtime | Chat, Agent, MCP server, CLI `tool` all call the same registry/`ToolRuntime` |
| No API keys in `systemConfig` | Cache / env / optional `apiKeyFile` only |
| Writes & rebuilds guarded | Confirm in GUI; agent needs explicit policy; cron defaults read-only |
| Cron ≠ unattended root shell | Allowlists, locks, budgets, audit trail |
| Flake purity | Knowledge & code stay inside `nixos/`; user state under `~/.config/ncc-assistant/` |

## Architecture (target)

```text
GUI (Chat | Tools | Agent | Jobs | Schedules | …)
        │
        ▼
 ChatSession ──► Agent Runner ──► Job store
        │              │
        └──────┬───────┘
               ▼
        Tool Registry
     (builtin | shell | mcp-client)
               ▼
          ToolRuntime
               │
     ┌─────────┼─────────┐
     ▼         ▼         ▼
 systemConfig  knowledge  external MCP servers
```

## Core phases (0–7)

| # | Plan | Summary |
|---|------|---------|
| 0 | [plans/00-status-quo.md](./plans/00-status-quo.md) | What exists today |
| 1 | [plans/01-tool-registry-and-mcp-client.md](./plans/01-tool-registry-and-mcp-client.md) | Registry, custom tools, MCP *client*, Tools UI |
| 2 | [plans/02-agent-mode.md](./plans/02-agent-mode.md) | On-demand agent (`ncc ai agent` + GUI) |
| 3 | [plans/03-jobs-and-history.md](./plans/03-jobs-and-history.md) | Job artifacts, logs, retry |
| 4 | [plans/04-schedules-and-timers.md](./plans/04-schedules-and-timers.md) | systemd timers / Nix schedules + Schedules UI |
| 5 | [plans/05-ui-integration.md](./plans/05-ui-integration.md) | Full GUI IA, navigation, UX requirements |
| 6 | [plans/06-hardening-and-audit.md](./plans/06-hardening-and-audit.md) | Policies, dry-run, approval queue, audit |
| 7 | [plans/07-notifications-and-presence.md](./plans/07-notifications-and-presence.md) | System notifications: Allow/Block/Wait, DND/playing |

**Dependency rule (core):** 1→2→3→4; 5 parallel with 1–2; 6 after 2; 7 with/after 2–3.

## Backlog phases (8–27)

Implement after core unless a plan says otherwise. Each item has its own plan file.

### NCC product / ops

| # | Plan | Summary |
|---|------|---------|
| 8 | [plans/08-diff-review-ui.md](./plans/08-diff-review-ui.md) | Side-by-side patch review, Apply selected |
| 9 | [plans/09-rollback-assistant.md](./plans/09-rollback-assistant.md) | Post-write/rebuild undo via backups/generations |
| 10 | [plans/10-config-drift-health.md](./plans/10-config-drift-health.md) | Periodic drift/health report |
| 11 | [plans/11-preflight-as-tool.md](./plans/11-preflight-as-tool.md) | Preflight callable by agent before rebuild |
| 12 | [plans/12-multi-host-profiles.md](./plans/12-multi-host-profiles.md) | Per-hostname/flake profiles |
| 13 | [plans/13-knowledge-sync.md](./plans/13-knowledge-sync.md) | Knowledge/registry sync from GUI |
| 14 | [plans/14-pinned-playbooks.md](./plans/14-pinned-playbooks.md) | One-click agent playbooks |

### Agent / automation

| # | Plan | Summary |
|---|------|---------|
| 15 | [plans/15-watchdogs.md](./plans/15-watchdogs.md) | Event triggers (failed rebuild, disk, …) |
| 16 | [plans/16-budgets-visible.md](./plans/16-budgets-visible.md) | Live step/token budgets in UI + notifications |
| 17 | [plans/17-agent-memory.md](./plans/17-agent-memory.md) | Durable short notes across runs |
| 18 | [plans/18-safe-tool-profiles.md](./plans/18-safe-tool-profiles.md) | Presets: read-only / config-writer / ops |

### Tools / MCP

| # | Plan | Summary |
|---|------|---------|
| 19 | [plans/19-mcp-marketplace.md](./plans/19-mcp-marketplace.md) | Curated MCP server templates |
| 20 | [plans/20-tool-rate-limits-cost.md](./plans/20-tool-rate-limits-cost.md) | Per-tool rate limits & cost estimates |
| 21 | [plans/21-export-registry.md](./plans/21-export-registry.md) | Export tools as MCP + OpenAPI |

### UI / desktop

| # | Plan | Summary |
|---|------|---------|
| 22 | [plans/22-system-tray-daemon.md](./plans/22-system-tray-daemon.md) | Tray: presence + pending approvals |
| 23 | [plans/23-global-shortcuts.md](./plans/23-global-shortcuts.md) | Global hotkeys pause / approvals |
| 24 | [plans/24-transcript-export.md](./plans/24-transcript-export.md) | Markdown/HTML transcript export |
| 25 | [plans/25-ui-compact-traces.md](./plans/25-ui-compact-traces.md) | Compact collapsible tool traces |

### Collaboration / quality

| # | Plan | Summary |
|---|------|---------|
| 26 | [plans/26-eval-harness.md](./plans/26-eval-harness.md) | Fixed Q&A / tool-expectation evals |
| 27 | [plans/27-red-team-mode.md](./plans/27-red-team-mode.md) | Adversarial prompt pack must be blocked |

## Feature map (checklist)

### Already shipped (see phase 0)

- [x] GUI chat (Qt6), terminal fallback
- [x] Streaming, Stop, markdown bubbles
- [x] Session save / continue
- [x] Model picker, vision gate for images
- [x] Auth prompt + credential cache
- [x] Built-in tools + MCP *server* (`ncc ai mcp`)
- [x] GUI confirm for write / rebuild tools

### Core planned (1–7)

- [ ] Unified tool registry (builtin / shell / mcp)
- [ ] MCP *client* (attach external servers)
- [ ] Tools panel in GUI
- [ ] Agent run (CLI + GUI) with goal + budget
- [ ] Job store + Jobs UI
- [ ] Declarative schedules (Nix) + optional user-local overrides
- [ ] systemd timers / oneshot agent units
- [ ] Schedules UI
- [ ] Dry-run / approval queue / audit log
- [ ] Kill-switch + hard budgets for unattended runs
- [ ] System notifications for agent decisions (Allow / Block / Wait)
- [ ] Presence / DND (“playing — don’t execute”)
- [ ] Confirm modes: always / writes-only / never

### Backlog planned (8–27)

- [ ] Diff-Review UI (Apply selected)
- [ ] Rollback assistant (backups / generations)
- [ ] Config drift / health report
- [ ] Preflight-as-tool
- [ ] Multi-host profiles
- [ ] Knowledge sync (GUI)
- [ ] Pinned playbooks
- [ ] Watchdogs (event triggers)
- [ ] Visible budgets
- [ ] Agent memory
- [ ] Safe tool profiles
- [ ] MCP marketplace / templates
- [ ] Per-tool rate limits & cost
- [ ] Export registry (MCP + OpenAPI)
- [ ] System tray daemon
- [ ] Global shortcuts
- [ ] Transcript export
- [ ] Compact tool-trace UI
- [ ] Eval harness
- [ ] Red-team mode

## Config surface (future sketch)

Not implemented — documents intent for phase docs:

```nix
{
  enable = true;
  endpoint = "https://llm.example.com/v1";

  allowWrite = true;
  mcpAllowWrite = false;
  allowRebuild = false;

  tools = {
    allowShell = false;
    mcpServers = { };
  };

  agent = {
    enable = true;
    maxSteps = 24;
    allowWrite = false;
    allowRebuild = false;
    confirm = "writes";
    profile = "read-only";  # phase 18
    notifications = {
      enable = true;
      timeoutSec = 300;
      onTimeout = "block";
    };
    schedules = { };
    # watchdogs = { };  # phase 15
  };

  # profiles.Gaming = { … };  # phase 12
}
```

User-local state (always outside Nix store):

```text
~/.config/ncc-assistant/
  credentials.json
  presence.json      # phase 7
  memory.jsonl       # phase 17
  sessions/
  tools/
  playbooks/         # phase 14
  jobs/
  schedules/
  approvals/         # phase 6
  knowledge-overlay/ # phase 13
```

## Scheduling decision (open)

See [plans/04-schedules-and-timers.md](./plans/04-schedules-and-timers.md):

- **A — Nix/systemd** (preferred SSOT)
- **B — User-local timers** (experimental overlay)

## Out of scope (for now)

- Forking Open WebUI / separate web SPA as primary UI
- Unrestricted shell tools without allowlist
- Unattended `allowRebuild = true` on cron by default
- Multi-user shared agent fleet / remote orchestration
- Voice I/O, mobile apps

## How to use these docs

1. Read phase 0 for baseline; implement **core 1–7** before most backlog items.
2. Each backlog plan lists dependencies — honor them.
3. When a feature ships, tick it here and set the plan **Status: done**.
4. Keep [USAGE.md](./USAGE.md) as the *current* operator guide.
