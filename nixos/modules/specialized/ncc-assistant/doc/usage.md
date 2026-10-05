# NCC AI Assistant

Chat with an LLM about your NixOS Control Center config, or expose the same
tools to Cursor / Claude Code via MCP. Full feature map: [roadmap.md](./roadmap.md).

## Enable (NCC host)

```nix
{
  enable = true;
  endpoint = "https://llm.example.com/v1";
  allowWrite = true;
  mcpAllowWrite = false;
  allowRebuild = false;

  agent = {
    profile = "read-only";
    confirm = "writes";

    # Opt-in schedules (uncomment / copy). Safe: playbook + dryRun + read-only.
    # schedules.daily-health = {
    #   enable = true;
    #   onCalendar = "*-*-* 03:15:00";
    #   playbook = "health-report";
    #   profile = "read-only";
    #   dryRun = true;
    #   maxSteps = 15;
    # };
    # schedules.weekly-module-audit = {
    #   enable = true;
    #   onCalendar = "Sun *-*-* 04:00:00";
    #   playbook = "unused-modules-dry-run";
    #   profile = "read-only";
    #   dryRun = true;
    #   maxSteps = 30;
    # };
  };
}
```

## Import from another flake

Pull this module (plus runtime) without copying a full NCC host tree:

```nix
inputs.ncc.url = "github:fr4iser90/NixOSControlCenter?dir=nixos";

# nixosSystem:
specialArgs = inputs.ncc.lib.mkNccSpecialArgs {
  inherit (pkgs) lib;
  systemConfig.modules.specialized.ncc-assistant.enable = true;
};
modules = [
  inputs.ncc.nixosModules.ncc-runtime
  inputs.ncc.nixosModules.ncc-assistant
];
```

Guide: [flake-exports.md](../../../../../docs/developing/flake-exports.md).

**Auth:** on 401/403 the GUI/CLI prompts once and caches
`~/.config/ncc-assistant/credentials.json` (0600). Optional `apiKeyFile` for
sops/agenix.

Rebuild after enabling so `ncc ai` / `ncc-assistant` packages are installed.

## Recommended schedules

| Name | When | Kind | Notes |
|------|------|------|--------|
| `daily-disk-probe` | 02:45 | **probe** | Tool-only; LLM only if root ≥ 85% |
| `daily-health` | 03:15 | agent | LLM health narrative |
| `weekly-module-audit` | Sun 04:00 | agent | unused modules (dry-run) |

Defaults are **off**. Load via **Schedules** tab or copy from `template-config.nix`.

```bash
# Probe only (no LLM)
ncc-assistant probe disk --threshold 85
ncc-assistant tool disk_nix_report --args '{"threshold_pct":85}'

# Escalate to advisor if over threshold
ncc-assistant probe disk --threshold 85 --escalate

# Force advisor even when OK
ncc-assistant probe disk --force --escalate
ncc-assistant playbook run disk-nix-gc-advisor
```

## GUI

```bash
ncc ai          # Qt window (default)
ncc ai gui
ncc ai chat     # terminal fallback
ncc ai companion   # desktop avatar + multi-chat (always-on-top)
# or: ncc-assistant-companion
# Sessions ▾ (F2 rename, Move to workspace) → companion-chats.json (empty 0-msg chats skipped)
# Resize · workspace/harness chips · MCP marketplace · templates with param dialog
# More → Theme (Dark/Midnight/Light) · avatar skin · inject NCC MCP into qwen/dsh
# Thinking/tools collapsed; multi-turn history folded into harness prompts.

ncc ai harness status              # native / qwen / dsh availability
ncc ai agent run --harness qwen --goal "…"
ncc ai agent run --verbose --goal "…"   # full thinking/tool dumps
# agent.harness / agent.codingHarness in systemConfig (auto routes git/coding templates)
```

Tabs: **Chat**, **Agent**, **Templates**, **Tools**, **Jobs**, **Workflows**,
**Schedules**, **Settings**.

**Retry / timeouts:** Chat and Companion show **Retry** after an error (resends the
last user message). Settings → **4c · LLM request**: HTTP timeout (default 300s)
and auto-retries on transient failures before the first streamed token
(`preferences.json`: `llm_timeout_sec`, `llm_retries`).

**Capacity & idle (Settings 4d):** `max_concurrency` (1–8), `idle_mode`
(`off` / `schedules` / `schedules+backlog`), `idle_after_min`, `idle_max_jobs`.
Agent / template / harness starts go through the capacity governor (“at capacity”
when full). Idle sweep (Companion timer) may start due schedules / `idle-ok`
templates when armed; presence `paused` disables idle.

**Daily workflows:** Data on **Workflows** tab / Companion Daily. **Morning Brief**
(schedule, sources, enable) is a **Plugins** tab feature — not Settings core.
CLI: `ncc ai workflows show|refresh|tasks|roadmap`.

**Doomscroll prevention:** Feature **plugin** under the **Plugins** tab (not
Settings, not MCP). Watch (Apps + Sites enums) → When → On interrupt → Session.
Sites drive match + nft domains. Defaults: off · Firefox · YouTube Shorts · 20 min ·
clips off · cooldown 30 · net block off · companion · pause+jump on.
Always-on NixOS hosts (like Windows hosts file):

```nix
# systemConfig … ncc-assistant
focus.hostsBlock.enable = true;
focus.hostsBlock.domains = [ "youtube.com" "www.youtube.com" "tiktok.com" ];
```

→ `networking.extraHosts` (0.0.0.0 / ::1). **Domains only** — not `/shorts/` path.
Timed lockout uses `ncc-focus-netblock` (nft + browser peer harvest + conntrack
flush). Shorts need CDN hosts (`googlevideo.com`, …) — included in the YouTube
site tags. Check `ncc ai focus status` → `net_block.active`.
CLI: `ncc ai focus status|tick|snooze`.

**Companion:** frameless overlay — drag avatar to move, resize via corner grip,
session picker (grouped by workspace), template/Daily/**Plugins**/tool/MCP/workspace icons.
Plugins panel: toggle enable, Configure dialog, Grant net-block (Doomscroll opt-in;
Polkit allows `ncc-focus-netblock` without password for active sessions).
Default chrome theme is **Dark** (More → Theme; also Midnight / Light).
Avatar animates idle / thinking / speaking / paused / error; idle badge when
sweep is armed.

## Agent

```bash
ncc-assistant agent run --goal "Check system health" --dry-run
ncc-assistant agent run --playbook health-report
```

Profiles: `read-only` (default), `config-writer`, `ops`  
Aliases: `cautious` → config-writer, `autonomous` → ops

## Templates / secrets / workspaces

Workflow cards (AGENTS.md maintainer, skills maintainer, GitHub code review, …)
live under the **Templates** tab. **Run once** = params + immediate run (no timer).
**⚙ Configure** = save instance + optional recurring schedule. Frequency uses
enums: Simple / Daily at time / Weekly / Cron field pickers (Advanced raw
OnCalendar only when needed). Secrets and workspaces are in **Settings** (or CLI).
Never put tokens in `systemConfig`.

```bash
# Named secrets (0600 under ~/.config/ncc-assistant/secrets.json)
ncc-assistant secrets set github_token
ncc-assistant secrets list

# Local git roots for MCP {{workspace.path}}
# GUI: Settings → Workspaces → Add… (folder picker) or Scan ~/Git…
ncc-assistant workspaces add --id ncc --path ~/Git/NixOSControlCenter
ncc-assistant workspaces list

# Catalog + instantiate
ncc-assistant templates list
ncc-assistant templates show github-code-review
ncc-assistant templates instantiate agents-md-maintainer --from params.json --schedule
ncc-assistant templates run <instance-id>
# Creators / rulebooks: roadmap-creator, design-concept-creator, task-breakdown,
# impressum-creator, precommit-creator, githooks-creator, agents-md-creator, …

# Daily workflows
ncc-assistant workflows refresh
ncc-assistant workflows tasks add "Ship docs" --priority p1
ncc-assistant workflows roadmap add "Ops cockpit" --horizon now
ncc-assistant workflows show

# MCP with workspace / secret bind
ncc-assistant mcp-install git --workspace ncc
ncc-assistant mcp-install github --secret GITHUB_PERSONAL_ACCESS_TOKEN=github_token
```

If the model list fails with **Auth failed**, update the LLM provider key (Chat
auth dialog or Settings → providers). Stale keys no longer keep an old model
selected as if the gateway still served it.

### Where LLM provider / model data lives

All under `~/.config/ncc-assistant/` (user-only, not `systemConfig`):

| File | Contents | Protection |
|------|----------|------------|
| `providers.json` | Endpoint list (e.g. old `llm.fr4iser.com`) | `0600`, **no** API keys |
| `credentials.json` | API keys per endpoint | `0600`, plaintext (needed for HTTP) |
| `preferences.json` | Last provider id + last model | `0600` |
| `secrets.json` | Agent/MCP tokens (`github_token`) | `0600`, plaintext |

**Old host still selected?** Settings → **1 · LLM providers** → Edit/Remove
`llm.fr4iser.com`, Add your current endpoint, then pick it in Chat’s provider
combo. Or delete that entry from `providers.json` / clear `last_provider_id` in
`preferences.json`.

## Jobs / playbooks / presence

```bash
ncc-assistant jobs list
ncc-assistant jobs show <id>
ncc-assistant jobs log <id>

ncc-assistant playbook list
ncc-assistant playbook run health-report --dry-run

ncc-assistant presence status
ncc-assistant presence pause --reason "gaming"
ncc-assistant presence resume
```

## Approvals / tray / watchdogs / rollback

Agent write/rebuild prompts show a desktop notification with **Allow / Block / Wait**
buttons (`notify-send --action`). You can also decide via CLI or tray:

```bash
ncc-assistant approve list
ncc-assistant approve allow <id>
ncc-assistant approve block <id>

ncc-assistant tray                 # or ncc-assistant-tray
ncc-assistant watchdog list
ncc-assistant watchdog fire rebuild-failed --force
ncc-assistant rollback
```

## Knowledge / export / eval / red-team

```bash
ncc-assistant knowledge sync --note "my note"
ncc-assistant export session <id> -o out.md
ncc-assistant export job <id>
ncc-assistant export latest --kind session
ncc-assistant eval run
ncc-assistant red-team
ncc-assistant serve-openapi --port 8765
```

## MCP (three layers — easy to confuse)

| Layer | Direction | Where | Companion UI |
|-------|-----------|--------|--------------|
| **NCC MCP server** | NCC → Cursor / Claude / qwen / dsh | `ncc-assistant-mcp` | **Inject NCC MCP into qwen/dsh** |
| **Marketplace / client MCPs** | External servers → NCC (client) | `~/.config/ncc-assistant/mcp-servers.json` | **Installed** + **Catalog** |
| **Harness-native MCPs** | Whatever qwen/dsh already have | `~/.qwen/settings.json` etc. | Not listed here (only NCC inject) |

**Catalog** ships templates under `templates/mcp/` (`git`, `github`, `filesystem`, `fetch`).
Install copies into `mcp-servers.json`. **Toggle** = enable/disable that entry;
**Remove** = delete it. Names like `git-aboutME` are *your* installed server ids
(not the catalog template name).

```bash
ncc ai mcp
# or
ncc-assistant-mcp
```

```json
{
  "mcpServers": {
    "ncc-assistant": {
      "command": "ncc-assistant-mcp",
      "args": []
    }
  }
}
```

`mcpAllowWrite` defaults to **false**. `apply_system` needs `allowRebuild` and
`confirm: "CONFIRM"`.

## Built-in tools (selection)

| Tool | Purpose |
|------|---------|
| `list_modules` | Registry listing |
| `read_module_config` | Read via config facade |
| `search_knowledge` | Knowledge + user overlay |
| `explain_path` | Path + registry + current config |
| `propose_config_patch` | Diff only |
| `apply_module_config` | Write (confirm) |
| `validate_config` | Parse-check Nix fragment |
| `apply_system` | Rebuild (guarded + optional preflight) |
| `run_preflight` | Prebuild script |
| `config_health_report` | Drift / health |
| `list_config_backups` / `list_boot_generations` | Rollback guidance |
| `memory_*` | Durable notes |

## Safety

- Kill-switch: `~/.config/ncc-assistant/DISABLE`
- Presence `paused` blocks mutating tools; schedules skip when paused
- Notification decisions timeout → `block` by default (`onTimeout`)
- Shell tools need `tools.allowShell` + optional `shellAllowlist`

## Debug

```bash
ncc-assistant tools
ncc-assistant tool list_modules --args '{}'
ncc-assistant tool search_knowledge --args '{"query":"ncc","limit":3}'
```
