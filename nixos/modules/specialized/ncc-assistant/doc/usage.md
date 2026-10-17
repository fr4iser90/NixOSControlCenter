# NCC AI Assistant

Chat with an LLM about your NixOS Control Center config, or expose the same
tools to Cursor / Claude Code via MCP.

**Definitions (Workflow / Skill / Cron / Tool / Plugin):** [surfaces.md](./surfaces.md)  
Feature map: [roadmap.md](./roadmap.md).

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

## Permission ladder (ceiling, grants, floor, budgets)

Autonomy is a ladder, not a switch: the **host is the ceiling**, a schedule or a single run
narrows it. Nothing below may widen it — asking for more than the ceiling **refuses the run**
instead of quietly doing less.

```nix
# systemConfig … ncc-assistant
grants.repoCeiling = "pr";   # observe → propose → commit → push → pr → merge → release
grants.budget = { maxPrsPerDay = 3; maxOpenAgentPrs = 5; };

agent.schedules.nightly-ship = {
  enable = true;
  onCalendar = "*-*-* 02:30:00";
  playbook = "autonomous-agent-ship";
  permissions = {
    repo = "pr";        # may only lower grants.repoCeiling
    system = "none";    # none | config-write | rebuild — ceiling is allowWrite / allowRebuild
    budget = { maxRunsPerDay = 1; };
  };
};
```

Left `null`, `permissions.repo` / `.system` derive from `dryRun` / `profile` / `allowWrite`, so a
host that sets nothing keeps behaving as before. `merge` and `release` still need the `CONFIRM`
token on top of their step.

```bash
ncc ai permissions show                              # ceiling, this run, ladder, floor, budget
ncc ai permissions show --grant repo=merge --json    # preview a run; exits 1 when it breaks the ceiling
ncc ai agent run --grant repo=pr --grant system=none --playbook autonomous-agent-ship
```

**Floor** — refused by code with no option that re-enables it. Each hit writes one `floor_denied`
line to `audit.jsonl`:

| Code | Refused because |
|------|-----------------|
| `denied_force_push` | `--force` / `-f`, a `+refspec`, or a `force` push-option |
| `denied_hook_bypass` | `--no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=…` |
| `denied_protected_branch` | pushing to, or merging onto, `main` / `master` |
| `denied_blanket_path` | `git add -A` / `.` / `*` — a commit takes a named pathset |
| `denied_secret_path` | pathset touches `.env*`, `*.pem`, `*credential*`, `secrets.json` |
| `denied_path_outside_repo` | pathset leaves the checkout (`../…`, absolute) |
| `denied_non_agent_branch` | commit / push / PR while not on a `ncc/…` branch |
| `denied_shell_git_write` | `git commit` / `push` / … inside a shell string — it carries no grant, no branch floor, no audit line, so the write capability is gone; reads survive |
| `merge_base_unknown` | `gh` returned no `baseRefName`, so the merge target is unknown — not merged |

A merge asks the **PR** where it lands (`gh pr view --json baseRefName`), never HEAD: HEAD says
where the commits are, the PR says where they end up. Outside a granted run the `CONFIRM` token
stays the human decision that keeps trunk reachable — the ladder binds agents, not the person
holding the token.

Budgets are counted **before** the LLM call, so a breach costs nothing. Day is UTC, `0` switches a
counter off, `null` keeps the default:

| Counter | Default | When exceeded |
|---------|---------|---------------|
| `maxRunsPerDay` | no limit | schedule skipped with `budget_runs`, the unit still exits 0 |
| `maxPrsPerDay` | 3 | work stops at `push` — branch on the remote, PR held for tomorrow |
| `maxDiffLines` | 800 | commit refused and unstaged, work stays local, task stays open |
| `maxOpenAgentPrs` | 5 | no new PR until one lands or is closed |

Every decision carries its actor (`schedule:nightly-ship`, `cli`, `companion`), so
`ncc-assistant approve list` reads back as "nightly-ship asked to merge, allowed 41 s later".
Not wired yet: `poll` triggers, schedule chains, and idle inheriting the day's lowest grant.

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

Tabs: **Chat**, **Agent**, **Workflows**, **Tools**, **Jobs**,
**Cron**, **Plugins**, **Settings**.

**Retry / timeouts:** Chat and Companion show **Retry** after an error (resends the
last user message). Settings → **4c · LLM request**: HTTP timeout (default 300s)
and auto-retries on transient failures before the first streamed token
(`preferences.json`: `llm_timeout_sec`, `llm_retries`).

**Capacity & idle (Settings 4d):** `max_concurrency` (1–8), `idle_mode`
(`off` / `schedules` / `schedules+backlog`), `idle_after_min`, `idle_max_jobs`.
Agent / template / harness starts go through the capacity governor (“at capacity”
when full). Idle sweep (Companion timer) may start due schedules / `idle-ok`
templates when armed; presence `paused` disables idle.

**Surfaces (Companion / GUI):** **Workflows** (once or Cron) ·
**Plugins** (desktop extras, e.g. Doomscroll) · **Tools** · **MCP** ·
**Workspaces** · **Cron**. There is **no Daily board**.
See [surfaces.md](./surfaces.md).

**Briefing:** workflow `workspace-brief` — run Once or schedule under
**Cron**. Not a plugin.

**Repo automation:** register a git root under Workspaces (★ active), then run
workflows (`autonomous-agent-run`, creators, `workspace-brief`, …)
Once or via Cron. Helpers: `ncc ai workflow audit|plan|task-start|task-finish|…`
(`task-finish` refuses PR if validators fail; `merge`/`bump` need `--confirm CONFIRM`).

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
flush) then navigates the feed tab to `about:blank` (wtype/xdotool) so cached
SPA clips cannot keep playing. Shorts include CDN hosts (`googlevideo.com`, …).
Check `ncc ai focus status` → `net_block.active` (uses lockout marker; raw nft
list often needs root). Needs `wtype` on Plasma Wayland for leave-tab.
CLI: `ncc ai focus status|tick|snooze`.

**Companion:** frameless overlay — drag avatar to move, resize via corner grip,
session picker (grouped by workspace), Workflows / Cron / Plugins / Tools / MCP / Workspaces.
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
OnCalendar only when needed). Cards that write prose also have **Language**
(English / Deutsch / Auto — Auto keeps the language the file already uses);
generators whose output is canonical or machine-format (SPDX licenses,
`.gitignore`, CODEOWNERS, CI YAML) have none on purpose. Secrets and workspaces
are in **Settings** (or CLI). Never put tokens in `systemConfig`.

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
# impressum-creator, privacy-policy-creator, precommit-creator, githooks-creator,
# agents-md-creator, workspace-audit, autonomous-agent-run, autonomous-agent-ship, …

# Workspace workflow (one project first)
ncc-assistant workflow audit --workspace myapp
ncc-assistant workflow plan --workspace myapp
ncc-assistant workflow next --workspace myapp --json
ncc-assistant workflow task-start --workspace myapp
ncc-assistant workflow task-finish --workspace myapp -m "workflow: fill gap"
ncc-assistant workflow resume --workspace myapp
# merge / bump ONLY with explicit confirm:
ncc-assistant workflow merge --workspace myapp --confirm CONFIRM
ncc-assistant workflow bump --workspace myapp --confirm CONFIRM --part patch
ncc-assistant workflow status

# Digest helpers (active workspace ★) — briefing UI is template workspace-brief
ncc-assistant workflows refresh
ncc-assistant workflows tasks add "Ship docs" --priority p1
ncc-assistant workflows roadmap add "Ops cockpit" --horizon now
ncc-assistant workflows show
ncc-assistant templates show workspace-brief

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

## Chat context & compaction

Every chat surface keeps one rolling transcript, so back-and-forth keeps its
thread. What is on file is measured, not guessed: the gateway's own `usage` from
the last response is the anchor, anything appended since then is estimated
(~4 chars/token, images flat 800), plus the fixed per-request floor (system
prompt + tool schemas).

**Observe**

| Surface | Reading | Manual compaction |
|---------|---------|-------------------|
| GUI chat | `ctx 42%` chip in the chat toolbar | **Compact** button (same toolbar) |
| Companion | `ctx 42%` button under the session picker | its menu → **Compact this chat** |
| `ncc ai chat` (REPL) | `/context` | `/compact` |
| CLI | `ncc ai context show [--session ID] [--json]` | `ncc ai context compact [--session ID] [--keep N]` |

Chip semantics: `~` prefix = no real `usage` yet (pure estimate, e.g. right
after a compaction); **bold** = at/over the threshold; `ctx ?` (Companion) = the
window could not be read — the chat itself is fine. Hover for used/window, free
tokens, threshold, whether auto-compaction is on, and how the window was found.

**Window size** is discovered per `endpoint + model`: llama.cpp `/props`,
Ollama `num_ctx` (falling back to the model's trained length), `/models`
`max_model_len`. A runtime cap always wins over a trained length. When nothing
advertises one, fallback is 8192 tokens.

**Automatic compaction** (like qwen-code): before a request whose projected size
crosses the threshold, older turns are replaced by one LLM summary and the
newest turns are kept verbatim. The threshold is qwen-code's own
`computeThresholds`: **85 % of the window, capped at `window − 33 000`**
(20 000 kept for the summary output + 13 000 buffer) whenever that cap is
positive — 6 963 tokens at an 8 192 window, 167 000 at 200 000. No extra safety
buffer: the pending user message is already counted when the check runs. A hard
`context length exceeded` error from the gateway triggers the same
compact-then-retry-once path. Tool calls and their results are never split.
Each compaction is reported once per surface
(`Context compacted — ~N tokens freed`).

```nix
# systemConfig … ncc-assistant  (all values in tokens)
agent.contextWindow = null;     # null = probe the gateway; 32768 = pin it (no probe)
agent.compactThreshold = -1;    # -1 = derive like qwen-code; >0 = used as-is
agent.autoCompact = true;       # false = never compact on its own (manual only)
```

`autoCompact = false` keeps the full transcript until you compact by hand, so an
over-long prompt fails instead of losing detail. Switching provider or model
re-reads the window; `--keep N` overrides how many newest turns survive.
External harness sessions (`agent.harness = "qwen" | "dsh"`) compact inside that
tool, not here.

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
| `ask_user` | Ask the human a question (options → chips) |
| `memory_*` | Durable notes |

### `ask_user` — the model asks instead of guessing

One tool, one card: question, short header and up to four options render where the chat
runs, and what you pick comes back to the model as the tool result.

| Surface | How you answer |
|---------|----------------|
| Companion / GUI | Option chips on the card; the free-text row always works; `Skip` = no answer |
| `ncc ai` (REPL) | Numbered options on stdin — `2`, or `1,2` when `multi_select`; other text goes verbatim, Enter skips |
| MCP / agent runs / schedules | No interactive surface → `{"ok": false, "error": "No interactive surface…"}` |

- The card is shown **before** the tool waits, so chips are live the moment the model asks.
- A question waits at most **600 s**; on timeout or `Skip` the tool returns `answered: false`
  plus a note not to ask again, so the run continues on stated assumptions instead of looping.
- `multi_select: true` collects every checked chip and is answered with `Send` (or `Enter`).
- A reloaded companion chat shows the question with the answer that was given; that card is
  closed — its worker is gone, so nothing could receive an answer any more.
- Questions only, never write approval: `apply_module_config` / `apply_system` still go
  through the confirm path, so a question can't stack a second prompt onto a write.

## Safety

- Kill-switch: `~/.config/ncc-assistant/DISABLE`
- Presence `paused` blocks mutating tools; schedules skip when paused
- Notification decisions timeout → `block` by default (`onTimeout`)
- Shell tools need `tools.allowShell` **and** a non-empty `tools.shellAllowlist`. An empty
  allowlist denies every command — enabling the shell is not a licence for any command.
- Written `0600`: `secrets.json`, `mcp-servers.json` (resolved tokens), `workspaces.json`,
  `approvals/*`, `audit.jsonl`
- State that would grow forever is pruned before each agent run, or on demand:

```bash
ncc ai maintenance run [--json]     # = ncc-assistant maintenance run
```

Keeps the newest 50 finished jobs (30 days max), the last 5000 `audit.jsonl` lines, and
deletes decided approvals older than 7 days. Running/pending jobs and undecided approvals
are never touched.

## Debug

```bash
ncc-assistant tools
ncc-assistant tool list_modules --args '{}'
ncc-assistant tool search_knowledge --args '{"query":"ncc","limit":3}'
```
