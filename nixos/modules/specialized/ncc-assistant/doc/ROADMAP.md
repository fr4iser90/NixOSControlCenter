# NCC AI Assistant — Roadmap

Status: **implemented on branch `feat/ncc-assistant-roadmap`** (core + backlog surfaces).  
Operator guide: [USAGE.md](./USAGE.md).

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
GUI (Chat | Tools | Agent | Jobs | Schedules | Settings)
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

| # | Plan | Status |
|---|------|--------|
| 0 | [plans/00-status-quo.md](./plans/00-status-quo.md) | **done** |
| 1 | [plans/01-tool-registry-and-mcp-client.md](./plans/01-tool-registry-and-mcp-client.md) | **done** |
| 2 | [plans/02-agent-mode.md](./plans/02-agent-mode.md) | **done** |
| 3 | [plans/03-jobs-and-history.md](./plans/03-jobs-and-history.md) | **done** |
| 4 | [plans/04-schedules-and-timers.md](./plans/04-schedules-and-timers.md) | **done** |
| 5 | [plans/05-ui-integration.md](./plans/05-ui-integration.md) | **done** |
| 6 | [plans/06-hardening-and-audit.md](./plans/06-hardening-and-audit.md) | **done** |
| 7 | [plans/07-notifications-and-presence.md](./plans/07-notifications-and-presence.md) | **done** |

## Backlog phases (8–27)

| # | Plan | Status |
|---|------|--------|
| 8 | Diff-Review UI | **done** (`DiffReviewDialog`, chat propose hook) |
| 9 | Rollback assistant | **done** (CLI `rollback`, GUI Jobs card, generations tool) |
| 10 | Config drift / health | **done** (`config_health_report` + playbook) |
| 11 | Preflight-as-tool | **done** (tool + `AGENT_REQUIRE_PREFLIGHT` gate) |
| 12 | Multi-host profiles | **done** (Nix `profiles` → env + hostname guard) |
| 13 | Knowledge sync | **done** (overlay + search prefer; Settings sync) |
| 14 | Pinned playbooks | **done** (builtins + CLI + Agent combo) |
| 15 | Watchdogs | **done** (JSON + CLI + Schedules UI; event fire) |
| 16 | Visible budgets | **done** (steps + exhaustion event; token placeholder) |
| 17 | Agent memory | **done** (tools + Settings list/forget) |
| 18 | Safe tool profiles | **done** (`read-only` / `config-writer` / `ops` + aliases) |
| 19 | MCP marketplace | **done** (templates + Tools install) |
| 20 | Rate limits & cost | **done** (per-tool caps + intervals; cost estimates light) |
| 21 | Export registry | **done** (MCP from registry + `serve-openapi`) |
| 22 | System tray | **done** (`ncc-assistant-tray` / `tray` CLI) |
| 23 | Global shortcuts | **done** (desktop Actions + user `.desktop` + in-app Ctrl+Shift+P/R) |
| 24 | Transcript export | **done** (MD export session/job/latest) |
| 25 | Compact tool traces | **done** (`ToolTraceWidget` in Chat) |
| 26 | Eval harness | **done** (`eval/cases.json` + `ncc ai eval run`) |
| 27 | Red-team mode | **done** (guards + playbook + CLI/GUI) |

## Feature map (checklist)

### Already shipped (phase 0)

- [x] GUI chat (Qt6), terminal fallback
- [x] Streaming, Stop, markdown bubbles
- [x] Session save / continue
- [x] Model picker, vision gate for images
- [x] Auth prompt + credential cache
- [x] Built-in tools + MCP *server* (`ncc ai mcp`)
- [x] GUI confirm for write / rebuild tools

### Core (1–7)

- [x] Unified tool registry (builtin / shell / mcp)
- [x] MCP *client* (attach external servers)
- [x] Tools panel in GUI
- [x] Agent run (CLI + GUI) with goal + budget
- [x] Job store + Jobs UI
- [x] Declarative schedules (Nix) + systemd timers
- [x] Schedules UI
- [x] Dry-run / approval queue / audit log
- [x] Kill-switch + hard budgets for unattended runs
- [x] System notifications for agent decisions (Allow / Block / Wait)
- [x] Presence / DND (`available` / `paused` / `autonomous`)
- [x] Confirm modes: always / writes-only / never

### Backlog (8–27)

- [x] Diff-Review UI (Apply selected)
- [x] Rollback assistant (backups / generations)
- [x] Config drift / health report
- [x] Preflight-as-tool
- [x] Multi-host profiles
- [x] Knowledge sync (GUI)
- [x] Pinned playbooks
- [x] Watchdogs (event triggers)
- [x] Visible budgets
- [x] Agent memory
- [x] Safe tool profiles
- [x] MCP marketplace / templates
- [x] Per-tool rate limits & cost
- [x] Export registry (MCP + OpenAPI)
- [x] System tray daemon
- [x] Global shortcuts
- [x] Transcript export
- [x] Compact tool-trace UI
- [x] Eval harness
- [x] Red-team mode

## Known follow-ups (not blockers)

- Token budget numbers need LLM usage fields when the gateway provides them.
- Watchdog *emitters* (systemd path units for failed rebuild / disk) are opt-in; library + CLI fire events today.
- OpenAPI surface is intentionally minimal (`/health`, `/tools`) on localhost.
- HTML transcript export not required for the MD path.
- Plasma kglobalaccel binding is documented; desktop Actions are installed via `.desktop`.
- Notification action buttons need a compositor that supports `notify-send --action` (Plasma does).

## Config surface

```nix
{
  enable = true;
  endpoint = "https://llm.example.com/v1";

  allowWrite = true;
  mcpAllowWrite = false;
  allowRebuild = false;

  tools = {
    allowShell = false;
    shellAllowlist = [ "systemctl status" "df" ];
    mcpServers = { };
  };

  agent = {
    enable = true;
    maxSteps = 24;
    allowWrite = false;
    allowRebuild = false;
    confirm = "writes";
    profile = "read-only";
    requirePreflightBeforeRebuild = false;
    notifications = {
      enable = true;
      timeoutSec = 300;
      onTimeout = "block";
    };
    tray.enable = false;
    schedules = { };
  };

  profiles.Gaming = {
    hostname = "Gaming";
  };
}
```

User-local state:

```text
~/.config/ncc-assistant/
  credentials.json
  presence.json
  memory.jsonl
  sessions/
  tools/
  playbooks/
  jobs/
  schedules/
  approvals/
  knowledge-overlay/
  watchdogs.json
  mcp-servers.json
  DISABLE                 # kill-switch
```

## How to use these docs

1. [USAGE.md](./USAGE.md) is the operator guide for the shipped product.
2. Plan files under `plans/` keep design intent; status above is authoritative.
3. Rebuild with the module enabled to pick up packages, timers, and env exports.
