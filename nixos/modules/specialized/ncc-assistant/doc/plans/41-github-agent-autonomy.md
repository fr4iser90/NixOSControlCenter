# GitHub Agent autonomy (multi-day + resume)

**Status: done.** Builds on [40-github-agent.md](./40-github-agent.md)
(analyze board). Does **not** supersede 40 — extends it with act/campaign.

**Linked from:** `doc/surfaces.md`, `doc/usage.md`, plan 40 “next”, Companion
GitHub rail (Act / Autopilot).

**User:** "kk den kompletten plan machen und dann implemen tieren , das der
agent dann auch autonmm mehre tage läuft , falls disconnected ausgeht er
wieder angeht vllt sogar da weitermacht etc"

**Name:** GitHub Agent autopilot (not a second agent).  
**Goal:** run for days; survive Companion disconnect/restart; continue the same
wave from disk.

---

## Why

v1 Start only analyzes and narrates. Operators need:

1. Rights that **block** writes (not prefs theatre).
2. Deterministic **docs stubs** for gaps (no invented Creator verbs).
3. A **campaign** queue that is the resume SSOT across nights.
4. **Idle / CLI tick** so work continues when the UI is gone.
5. Autopilot modes in Companion UX (off → analyze → act-safe).

## Architecture

```
snapshot.json  ──build──►  campaign.json (queue/done/skipped/status)
                                │
                     tick (N items / run)
                                │
              policy gate → stub writer → mark Daily task done
                                │
              idle sweep / CLI / Companion Act button
```

**Resume spine:** `~/.config/ncc-assistant/github-agent/campaign.json`.  
Jobs remain audit trails; they do **not** need mid-run resume.  
Companion death leaves campaign `running`; next tick continues.

## Autopilot modes

| Mode | Behavior |
|------|----------|
| `off` | Manual Start / Act only |
| `analyze` | Idle may re-analyze when snapshot stale |
| `act-safe` | Idle/CLI tick applies **docs** stubs under policy |

Never auto: git commit, push, PR, delete, archive decisions, remote FS.

## Policy (enforced on every apply)

Prefs under `preferences.json` → `githubAgent`:

| Key | Role |
|-----|------|
| `allowWrite` | master write switch (default false) |
| `confirm` | `always` blocks unattended tick; `writes`/`never` allow docs when allowWrite |
| `allowlist` | if non-empty, only these workspace ids |
| `denylist` | never write (untouched) |
| `writeClasses` | default `["docs"]` — only these classes apply |
| `dirtyPolicy` | `skip` (default) \| `abort` — never write dirty trees in v1 |
| `maxPerTick` | budget 1–20 (default 6) |
| `autopilot` | `off` \| `analyze` \| `act-safe` |
| `analyzeStaleHours` | re-analyze threshold for analyze mode (default 24) |

Write class **docs** gaps: `agents-md`, `impressum`, `privacy`, `skills`.

## Campaign lifecycle

1. **arm** from latest snapshot (or analyze-then-arm): build queue, prefer clean
   worktrees, p0 before p1, skip archive / deny / missing path.
2. **tick**: apply up to `maxPerTick`; persist after each item.
3. **pause** / **resume** / **status**.
4. **done** when queue empty (skipped stay in history).

## Surface

- CLI: `ncc ai github-agent arm|tick|status|pause|resume|act` (+ rights extended)
- Companion GitHub panel: Act wave / Autopilot / Pause / campaign status line
- Idle: `maybe_sweep` also runs analyze-or-tick when autopilot ≠ off

## Acceptance

1. With `allowWrite=false`, tick applies nothing.
2. Denylist / dirty / archive never written.
3. Kill Companion mid-campaign → `tick` continues from campaign.json.
4. Autopilot `act-safe` + idle applies ≤ maxPerTick docs stubs.
5. Gates green.

## Checklist

- [x] `github-agent/campaign.json` store
- [x] policy prefs + enforcement
- [x] deterministic docs stubs
- [x] arm / tick / pause / resume
- [x] CLI + Companion + idle hook
- [x] tests + `tests/run-gates.sh` exit 0
- [x] `usage.md` / `surfaces.md` / link from plan 40
