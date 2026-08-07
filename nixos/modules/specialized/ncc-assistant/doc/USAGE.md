# NCC AI Assistant

Chat with an LLM about your NixOS Control Center config, or expose the same
tools to Cursor / Claude Code via MCP. Full feature map: [ROADMAP.md](./ROADMAP.md).

## Enable

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
```

Tabs: **Chat**, **Agent**, **Tools**, **Jobs**, **Schedules**, **Settings**.

## Agent

```bash
ncc-assistant agent run --goal "Check system health" --dry-run
ncc-assistant agent run --playbook health-report
```

Profiles: `read-only` (default), `config-writer`, `ops`  
Aliases: `cautious` → config-writer, `autonomous` → ops

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

## MCP

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
