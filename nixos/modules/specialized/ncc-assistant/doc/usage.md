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

A **repository** may run below that ceiling without waiting for a host rebuild — one committed file:

```json
{ "version": 1, "repo": "commit" }
```

`.ncc/permissions.json` narrows the repo axis for every run in that checkout, and nothing else:
there is no `system` key — the machine is the host's to bound, and a file that claims it is
refused rather than ignored. It is read out of `HEAD`, never the working tree, because the working
tree is exactly what a bounded run is allowed to write; deleting, widening or corrupting the file
on disk moves the ceiling by nothing at all. It only ever lowers: a file naming a step *above* the
one the run holds is recorded `ceiling_ignored=<step>` and the grant stays the narrower answer.
A file the ladder cannot parse floors the axis instead of reading as absent — the audit line says
`ceiling=repo_ceiling_invalid` and `permissions show` prints the same token, so "my repo lowered
nothing" and "my repo's file is broken" stay two different answers.

The owner commits it by hand. A run may not touch it: see `denied_repo_ceiling_path` below.

**Floor** — refused by code with no option that re-enables it. Each hit writes one `floor_denied`
line to `audit.jsonl`:

| Code | Refused because |
|------|-----------------|
| `denied_force_push` | `--force` / `-f`, a `+refspec`, or a `force` push-option |
| `denied_hook_bypass` | `--no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=…` |
| `denied_protected_branch` | pushing to, or merging onto, `main` / `master` |
| `denied_blanket_path` | `git add -A` / `.` / `*` — a commit takes a named pathset |
| `denied_secret_path` | pathset touches `.env*`, `*.pem`, `*credential*`, `secrets.json` |
| `denied_repo_ceiling_path` | the run stages **or untracks** anything under `.ncc/` — the file that lowers its own ladder is the owner's, in either direction of the index |
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
Schedules can also wait on each other — see `after = "…"` below.

## Confirm: who answers the prompt

`agent.confirm` (host default `writes`) decides **which** calls get asked about:
`always` = every tool, `writes` = write/rebuild levels, `never` = nobody. On a interactive run
(`ncc ai`, the GUI, MCP) that question goes to a person — notification, approve dialog, 300 s
before it counts as denied.

On a **schedule there is no person, and the grant answers instead.** The approval for a timer is the
`permissions.*` you wrote in Nix at deploy time: a granted `system = "config-write"` lets the unit's
write through immediately, and a refused one names the rule that refused it
(`grant_insufficient`, `confirm_without_grant`) instead of reporting a click nobody made. One
`confirm_answered` line per answered prompt, with the grant's actor. So a schedule that needs a
prompt to proceed was never runnable unattended — that is a config error, and it reads like one:
`confirm = "always"` on a schedule refuses non-ladder tools with `confirm_needs_human`
rather than waiting out the timeout.

```nix
agent.confirm = "writes";                 # the host's declaration
agent.schedules.nightly-ship.confirm = "always";  # may ask MORE than the host
agent.schedules.nightly-audit.confirm = "never";  # refused: clamped to "writes" + eval warning
```

**`confirm` may only ever ask more, never less** — narrowing moves toward `always`, which is the
opposite direction to a permission-ladder step, so it has its own clamp. The rule holds at
evaluation (the unit is handed the narrowed value and the disagreement warns), in the wrapper (an
`AGENT_CONFIRM` set in the environment may not widen it either), and on the command line:

```bash
ncc ai agent run --goal "…" --confirm always   # ok — asks more than the host
ncc ai agent run --goal "…" --confirm never    # exit 2: may ask more, never less
ncc ai permissions show                        # prints the effective confirm mode
```

An unknown value, an empty one, or a wider ask than the host falls back to the host's mode — the
narrow stage is always the unit's or the host's, never the caller's. Without a grant on the process
at all (`ncc ai` typed by hand), nothing changed: the person at the prompt is still the approver.

## Which account a schedule runs as

`agent.runAsUser` names the account every scheduled run executes as. It is a **host-wide** choice:
one account for all schedules, never one per schedule — what differs per schedule is only whether it
keeps root (below).

**Default (`null`) — root, borrowing a home.** The unit stays root and the run preamble *guesses* a
home: it walks the normal users in `users.users` and takes the first one owning a
`~/.config/ncc-assistant`. That is a root process reading that person's files — secrets, sessions,
workspaces — while the audit line says only `schedule:<id>`. It is also why agent git verbs died as
`dubious ownership` refusals: git compares the process uid against the repository owner, and a root
process never matches a repository owned by you. `safe.directory` does not fix this; it only hushes
git's complaint for a process that still holds root.

```nix
agent.runAsUser = "alice";   # must be a key in users.users, else evaluation refuses
```

Three things change at once: the unit gets `User=alice`; `HOME` and `XDG_CONFIG_HOME` come from
`users.users.alice.home` instead of being guessed, so a timer can no longer read a home it was not
granted; and actor and file owner become the same uid, which is what lets an operator read
`~/.config/ncc-assistant/audit.jsonl` and know whose files each line actually touched. Check what a
live unit carries:

```bash
systemctl show -p User ncc-assistant-schedule-<id>.service
ncc ai permissions show                        # the grant this run resolved, not the declared one
```

**The one exception, named at evaluation.** A schedule whose *resolved* grant reaches
`system = "config-write"` or `"rebuild"` keeps root even when `runAsUser` is declared — `/etc/nixos`
and `nixos-rebuild` both need it, and a run denied at the write its own grant authorised would read
as a broken agent rather than as a wrong expectation. Nix prints which schedules those are
(`keeps running as root although agent.runAsUser = …`) so nobody reads the host as "all runs
unprivileged"; lower `permissions.system`, `allowWrite` or `allowRebuild` on that schedule to drop it
to the declared account too.

**Chained schedules.** The wake step (`ExecStartPost=`) is prefixed `+`, so that one line keeps root
— a plain account may not ask systemd to start a sibling unit. The *decision* to wake is still asked
of the run's own account through `runuser`, because `ncc-assistant` appends it to `audit.jsonl` and a
root-owned audit file inside the operator's home would lock the GUI out of the history this run made.
`ExecStart=` keeps its restrictions, so the agent itself still never gets `systemctl`.

A declared account that is not a key in `users.users` fails evaluation by name rather than producing
a unit whose `User=` systemd would refuse at start.

## Poll schedules (change-driven, not clock-driven)

A poll fires on a monotonic interval and **skips the run when nothing changed** — it is the only
schedule kind that can be cheap enough to run every fifteen minutes:

```nix
agent.schedules.workspace-drift = {
  enable = true;
  trigger = "poll";
  pollInterval = "15min";
  pollWatch = [ "workspace:ncc" "file:/var/lib/ncc/facts.json" ];
  permissions = { repo = "propose"; system = "none"; };
};
```

The timer gets `OnBootSec=`/`OnUnitActiveSec=` only: no `OnCalendar`, no `Persistent` — a poll has
no missed slot to catch up, and a boot would otherwise stack every interval since shutdown into
one model call. `pollWatch` is what the change hash is computed over: `workspace:<id>` hashes HEAD,
branch and `git status --porcelain` (an uncommitted edit counts), `file:/abs/path` hashes the bytes;
a file that does not exist is a state too, so the tick it appears in is not skipped.

The hash is compared **before** the budget counters, the lock and the first LLM call, and it is
written only when a run *finishes*: an unchanged tick costs nothing and is not charged to
`maxRunsPerDay`, and a run that crashed or was cancelled retries the same state instead of
burning it. The unit exits 0 with `poll_unchanged` — systemd must not see 5 000 failed units a day.

Asking for something the guard cannot read is a **refusal**, never an "unchanged": an unregistered
workspace id or an unreadable file yields `poll_state_unknown`. That is deliberate — a gate that
guesses "unchanged" once makes the schedule quietly never run again. Evaluation refuses the shapes
that could only burn a model (a poll without `pollInterval` or `pollWatch`, an unusable watch entry,
`trigger = "poll"` on a probe, `pollWatch` on a calendar schedule, a calendar without `onCalendar`).
Read it back with `ncc ai permissions show` — the poll gate and its watch list are in the payload.

## Chained schedules (after another schedule completed)

`after` makes one schedule's completion the trigger for another, so `audit → ship` is declared
instead of two timers guessed apart:

```nix
agent.schedules.nightly-audit = {
  enable = true;
  onCalendar = "*-*-* 03:00:00";
  permissions = { repo = "propose"; system = "none"; };
  goal = "Audit the config and write the report.";
};
agent.schedules.ship-after-audit = {
  enable = true;
  after = "nightly-audit";          # no onCalendar: nothing but the completion wakes it
  permissions = { repo = "pr"; system = "none"; };
  goal = "Ship what the audit found.";
};
```

A chained schedule gets **no timer** unless it also sets `onCalendar` (then the clock runs as
well, and one completion still starts it only once). systemd cannot express this itself:
`OnUnitInactiveSec=` is measured relative to *the unit the timer itself activates*, so a timer can
never wait on a sibling schedule. The upstream unit's `ExecStartPost` asks
`ncc-assistant chain release --schedule <id>` and starts the dependents only if that answers yes —
inside a store script built at evaluation time, so the agent's own shell tools never hold
`systemctl` and finishing a chain grants a run no new capability.

Nothing woke means nothing was claimed. A run the chain, poll or budget gate held still exits 0,
and a `completed` left on disk by an *earlier* start of the same unit proves nothing about this
one, so the release checks the outcome recorded by this `$INVOCATION_ID` and refuses otherwise.
The downstream checks for itself before the budget counters and the first LLM call and skips with
one of `chain_upstream_unknown` / `chain_upstream_not_completed` / `chain_upstream_acted` —
`unknown` is never read as `completed`, so "nothing ran" and "it finished" stay different answers.

A completion is spent by a **finished** run only: a downstream that crashed or was cancelled keeps
its wake-up, one completion starts it exactly once, and the next completion wakes it again. Only a
schedule's own unit may record an outcome — a human `ncc ai agent run` and the idle sweep write
nothing, so neither can fake a completion for something waiting on it.

Evaluation refuses a chain that could only sit silent: `after` pointing at itself, at an id no
schedule on this host declares (the message lists the ids that do), at a schedule that is switched
off, at a `kind = "probe"` schedule, or around a loop. Read it back with
`ncc ai permissions show` — the run's `after`, how that upstream last ended and when this schedule
acted on it are all in the payload; `ncc ai chain release --schedule <id>` exits 0 only when
waking is allowed.

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

### What a server needs to start

A marketplace template launches through a launcher the host owns: `uvx` (from `uv`) for the
git / github / fetch servers, `npx` (from node) for filesystem. `mcp-install` therefore refuses
a template whose `command` is not on PATH and writes nothing — the alternative was reporting
success, storing the resolved token, and letting a later unattended run discover that the server
could never start. The wrapper's PATH declares `uv`, `gh` and `git`; anything else is the host's
to install.

### The credential a GitHub verb carries

`workflow pr` / `merge` and the Daily digest shell out to `gh`, and a schedule has no terminal to
run `gh auth login` in. Resolution, narrowest first:

1. an ambient `GH_TOKEN` / `GITHUB_TOKEN` — the unit said so out loud (`Environment=`, or the
   account `agent.runAsUser` names); left exactly as it is;
2. the `github_token` secret (`ncc-assistant secrets set github_token`) — the same credential the
   `github` MCP template already requires;
3. neither → `gh` falls back to the login state of the account the run carries, which is the
   documented path for a run a human set up by hand.

The credential is built for one `gh` invocation and never merged into the run's own environment,
so an allowlisted shell command, the external harness or a git hook cannot inherit a GitHub
credential it was never granted. The run's audit actor names *who* the run carried; it is not a
GitHub identity — the credential above is what authenticates.

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
ncc-assistant playbook run project-drift-audit

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
| `portfolio_drift_report` | Local project portfolio: folder vs remote vs registry |
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
