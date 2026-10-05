# Phase 34 — Ops cockpit · idle automations · daily workflows · rulebook generators

Status: **done**  
**Parent:** [roadmap.md](../roadmap.md)  
**Depends on:** companion (29–33), agent templates (28), schedules (4), jobs (3), presence (7), harness (30)  
**Audience:** single-shot / multi-slice implementers — this file is the locked product brief.

## Problem

Phases 0–33 shipped chat, agent, schedules, companion, harness, templates. What’s still
missing for day-to-day **repo ops** is a coherent “control plane”:

1. **Capacity settings** — max concurrency for agents / harness runs / scheduled jobs.
2. **Idle mode** — when the user is away, optionally spend spare capacity on backlog
   schedules / maintenance templates (not while actively chatting).
3. **Daily workflow surface** — Issues / PRs / checks / open tasks visible in one place
   (Companion + GUI), not buried in `gh` CLI.
4. **Creator templates** — Roadmap author, Design-concept author, and **rulebook
   generators** (Impressum, pre-commit, git hooks, AGENTS/skills packs, …) as first-class
   agent templates with enums, not free-text chaos.
5. **Task / roadmap store** — durable goals the user can track, prioritize, and feed
   into idle / daily runs.

## Product north star

```text
┌ Companion / GUI ─────────────────────────────────────────────┐
│ Daily: Issues · PRs · Checks · My tasks · Roadmap chips      │
│ Settings: maxConcurrency · idleMode · idleAfterMin · …       │
│ Templates: Run once | Schedule | Creators / Rulebooks        │
└───────────────┬──────────────────────────────────────────────┘
                │
                ▼
     Capacity governor (concurrency + idle policy)
                │
     ┌──────────┼──────────┐
     ▼          ▼          ▼
  Agent/Job   Schedules   Idle sweep
  (interactive) (timers)  (when idle ≥ N min)
```

---

## A — Runtime settings (preferences + Settings UI)

Store under `~/.config/ncc-assistant/preferences.json` (and optional Nix defaults later).

| Key | Type | Default | Meaning |
|-----|------|---------|---------|
| `max_concurrency` | int 1–8 | `2` | Max simultaneous agent/harness/template jobs |
| `idle_mode` | enum `off` \| `schedules` \| `schedules+backlog` | `off` | What may run when idle |
| `idle_after_min` | int 5–240 | `15` | Minutes without user interaction before idle |
| `idle_max_jobs` | int 1–4 | `1` | Cap on idle-started jobs per sweep |
| `daily_digest_enable` | bool | `true` | Build daily Issues/PRs/tasks snapshot |
| `daily_digest_on_calendar` | OnCalendar via FrequencyPicker | `*-*-* 08:30:00` | When digest refreshes |
| `workflow_providers` | enum list | `["github"]` | Sources for Issues/PRs (github first) |

**UI:** Settings → new group **“4d · Capacity & idle”** + **“4e · Daily workflows”**.  
All values via **enums / spinboxes** — no free-text for concurrency/idle.

**Enforcement:** job/agent/template/harness start paths consult a small
`capacity.py` (`try_acquire` / `release` / `active_count`). Queue or reject with clear UI.

---

## B — Idle mode

### Behaviour

1. Companion + GUI report **last user activity** (send, click, focus, template run).
2. A lightweight timer (tray/companion presence loop or `ncc-assistant` idle daemon
   hook) checks: `now - last_activity >= idle_after_min` **and** `idle_mode != off`
   **and** presence ≠ `paused`.
3. Idle sweep (at most every N minutes):
   - Prefer **enabled user schedules** that are “due / overdue / low priority backlog”.
   - Optionally run tagged templates `tags: ["idle-ok", "maintenance"]`.
   - Respect `max_concurrency` and `idle_max_jobs`.
   - Never auto-run `ops` / write profiles unless instance explicitly `idleAllowWrite`.
4. When user returns (activity), **do not** cancel running jobs; stop *starting* new idle jobs.

### Non-goals (idle v1)

- Stealing GPU from gaming (optional later: pause if fullscreen / gamescope).
- Cloud remote workers.

---

## C — Daily workflows surface (Issues / PRs / checks / tasks)

### Data model (`~/.config/ncc-assistant/workflows/daily.json`)

```json
{
  "version": 1,
  "updatedAt": "…",
  "workspaceId": "agent-kernel",
  "issues": [{"id":"…","title":"…","url":"…","labels":[],"state":"open"}],
  "pullRequests": [{"id":"…","title":"…","url":"…","draft":false,"checks":"pending|pass|fail"}],
  "tasks": [{"id":"…","title":"…","status":"todo|doing|done","priority":"p0|p1|p2"}],
  "roadmap": [{"id":"…","title":"…","horizon":"now|next|later"}]
}
```

### Sources

| Source | How |
|--------|-----|
| GitHub Issues/PRs | `gh` CLI or GitHub MCP + `github_token` secret; scoped to active workspace remote |
| Local tasks / roadmap | User CRUD in GUI + companion; creators can append |
| Checks | `gh pr checks` / commit status when PR listed |

### UI

- GUI tab **Workflows** (or section under Jobs): filters Issues / PRs / Tasks / Roadmap.
- Companion icon **Daily** → compact list (open PRs needing review, failing checks, top tasks).
- **Refresh** button + schedule via `daily_digest_on_calendar`.
- Enums for status/priority/horizon — no free status strings.

---

## D — Task & Roadmap store

| Entity | Fields (enums where noted) |
|--------|----------------------------|
| Task | `id`, `title`, `body?`, `status` enum, `priority` enum, `workspaceId?`, `links[]`, `createdAt` |
| RoadmapItem | `id`, `title`, `horizon` enum `now\|next\|later`, `parentId?`, `taskIds[]` |

**APIs:** `list/add/update/complete` in Python module `workflows.py` (or `tasks.py`).  
**CLI:** `ncc ai workflows tasks …`, `ncc ai workflows roadmap …`.  
**Creators** (below) write into this store as their primary side-effect (plus optional MD export).

---

## E — Creator & rulebook agent templates

Ship as `templates/agents/*.json` + skills under module prompts / `.agents/skills` patterns.
Each template: **enum params**, optional workspace, **Run once** default, schedule optional.

### E1 — Creators (planning / product)

| Template id | Purpose | Key outputs |
|-------------|---------|-------------|
| `roadmap-creator` | Turn goals/notes into roadmap chips + optional `doc/roadmap` section draft | RoadmapItems + MD snippet |
| `design-concept-creator` | Structured design brief (problem, users, flows, non-goals, visuals) | MD under workspace `doc/` or `design/` |
| `task-breakdown` | Goal → prioritized Task list | Tasks in store |

### E2 — Rulebook / repo hygiene generators

| Template id | Purpose | Typical artifacts |
|-------------|---------|-------------------|
| `impressum-creator` | DE Impressum / legal stub from enums (entity type, contact fields) | `impressum.md` / site page stub — **user text only for names/address** |
| `precommit-creator` | Generate/extend `.pre-commit-config.yaml` from enum hook packs | pre-commit config |
| `githooks-creator` | Wire repo hooks (align with NCC `scripts/install-git-hooks.sh` patterns) | `.githooks/*` + install note |
| `agents-md-creator` | Scaffold/refresh `AGENTS.md` for a workspace (laws, layout) | `AGENTS.md` draft (diff-first) |
| `skill-pack-creator` | New `.agents/skills/<name>/SKILL.md` from enum domains | skill folder |
| `editorconfig-creator` | `.editorconfig` from language enum set | `.editorconfig` |
| `license-chooser` | SPDX license enum → `LICENSE` | license file |

**Rules for generators:**

- Prefer **propose diff / write with confirm** (`config-writer` or dry-run first).
- Never invent legal advice; Impressum template is a **structured stub** with required enums
  (entity: GmbH/Einzel/…, country DE/AT/CH, contact fields).
- Git hooks / pre-commit must match **existing NCC gate philosophy** (no `--no-verify` culture).

---

## F — Companion / GUI integration checklist

| Surface | Work |
|---------|------|
| Settings 4d/4e | concurrency, idle, daily digest calendar (FrequencyPicker) |
| New Workflows page | Issues/PRs/Tasks/Roadmap lists + refresh |
| Companion toolbar | Daily icon; idle badge on avatar when idle sweep armed |
| Templates catalog | New creator/rulebook cards; tags `creator`, `rulebook`, `idle-ok` |
| Capacity | All `run_instance` / agent / harness starts go through governor |
| Presence | `paused` disables idle; `autonomous` may allow idle writes only if flagged |

---

## G — Implementation slices (suggested order)

| Slice | Deliverable | Priority |
|-------|-------------|----------|
| **A** | `preferences` keys + Settings UI + `capacity.py` gate | P0 |
| **B** | Idle detector + sweep (schedules only) | P0 |
| **C** | Workflows store + GitHub digest (`gh`) + GUI list | P0 |
| **D** | Companion Daily panel | P1 |
| **E** | Task/Roadmap CRUD + CLI | P1 |
| **F** | Creator templates (roadmap, design, task-breakdown) | P1 |
| **G** | Rulebook templates (precommit, githooks, impressum, agents-md, …) | P1 |
| **H** | Idle + backlog templates (`idle-ok`) + docs/tests/gates | P2 |

---

## Non-goals (phase 34)

- Full project-management clone (Jira/Linear).
- Binding legal counsel / tax advisor automation.
- Remote CI orchestration beyond showing check status.
- Cubism Live2D / true ACP SDK (still out of scope from 33).

## Acceptance (phase done when)

- [x] `max_concurrency` enforced (third job waits or surfaces “at capacity”)
- [x] Idle mode off by default; when on, after N minutes starts ≤ `idle_max_jobs` read-only schedule/template
- [x] Daily Workflows shows Issues/PRs (GitHub) + local tasks for active workspace
- [x] Roadmap/task creators write to store; rulebook templates produce gated file proposals
- [x] Frequency/idle/concurrency = enums/spinboxes only
- [x] `bash tests/run-gates.sh` exit 0; usage.md + this plan updated

## Test plan

- Unit: capacity acquire/release; idle eligibility; digest JSON shape
- AST: Settings 4d/4e, Workflows page, new template ids present
- Manual: concurrency=1 blocks double harness; idle after 1 min test pref; Run once impressum dry-run

---

## Single-shot GOAL prompt

Copy everything in the block below into Companion / Agent / coding harness as the **goal**.

```text
GOAL — NCC Assistant Phase 34 (Ops cockpit · idle · daily workflows · rulebooks)

Implement the locked brief in:
  nixos/modules/specialized/ncc-assistant/doc/plans/34-ops-cockpit-idle-rulebooks.md

Respect NCC hard laws (AGENTS.md): discovery helpers only, docs only under module doc/,
tests only under repo-root tests/, never touch live /etc/nixos, run
`bash tests/run-gates.sh` to exit 0 before claiming done. Do not tell user to
`ncc system-update` unless gates are green.

SHIP THESE FEATURES (A→H as needed, but leave the tree coherent):

1) Capacity & preferences
   - preferences.json: max_concurrency (1–8, default 2), idle_mode
     (off|schedules|schedules+backlog), idle_after_min (5–240, default 15),
     idle_max_jobs (1–4), daily_digest_enable, daily_digest_on_calendar
     (FrequencyPicker / OnCalendar), workflow_providers enum list.
   - Settings UI groups “Capacity & idle” and “Daily workflows” with spinboxes/enums only.
   - capacity.py governor: try_acquire/release; wire agent, run_instance, harness,
     companion template runs. Clear “at capacity” UX.

2) Idle mode
   - Track last user activity (GUI+Companion).
   - When idle_mode≠off, presence≠paused, and idle_after_min elapsed: start up to
     idle_max_jobs of due schedules and/or templates tagged idle-ok (read-only /
     dry-run unless idleAllowWrite). Stop starting when user returns; don’t kill
     in-flight jobs.

3) Daily workflows surface
   - Persist ~/.config/ncc-assistant/workflows/daily.json (issues, pullRequests,
     tasks, roadmap) with enum statuses.
   - Refresh via gh (or GitHub MCP) for active workspace remote; show in new GUI
     Workflows page + Companion “Daily” list (PRs needing review, failing checks,
     top tasks). Schedule refresh with FrequencyPicker (local system time).

4) Tasks & roadmap store
   - CRUD APIs + CLI for tasks (status/priority enums) and roadmap items
     (horizon now|next|later). Creators write here.

5) Creator templates (templates/agents + skills)
   - roadmap-creator, design-concept-creator, task-breakdown
   - Run once by default; enum params; optional MD export into workspace doc/

6) Rulebook generator templates
   - impressum-creator (DE stub; entity/country enums; free text only for
     legal name/address), precommit-creator, githooks-creator (align with NCC
     .githooks / install-git-hooks), agents-md-creator, skill-pack-creator,
     editorconfig-creator, license-chooser (SPDX enum).
   - Diff-first / confirm writes; no inventing legal advice; pre-commit/hooks
     must not encourage skipping gates.

7) Docs & tests
   - Update usage.md + roadmap.md pointer to phase 34.
   - Tests under tests/ncc-assistant/ for capacity, idle eligibility, digest shape,
     template ids AST.
   - bash tests/run-gates.sh → exit 0.

NON-GOALS: Jira clone, Live2D Cubism SDK, true ACP bidirectional SDK, legal counsel,
remote CI orchestration beyond check status display.

Deliver working code + green gates; keep UX enum-driven; reuse FrequencyPicker /
existing template Run-once / companion shell patterns from phases 28–33.
```

## How to use this file

1. Keep this MD as the SSOT while implementing (update checkboxes when slices land).
2. Paste the **Single-shot GOAL prompt** into `ncc ai companion` / `ncc ai agent` /
   qwen-or-dsh harness with coding workspace = this repo.
3. If the run is too large for one shot, feed **one slice letter (A–H)** per turn and
   point at this file’s slice table.
