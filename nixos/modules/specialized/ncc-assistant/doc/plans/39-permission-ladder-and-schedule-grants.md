# Phase 39 — Permission ladder & per-schedule grants

**Status:** L1–L11 + L13 + L14 done · L12 open
**Parent:** [roadmap.md](../roadmap.md)
**Depends on:** phase 38 (grants are scoped to a repo identity), phase 22 (approvals), schedules
**Unblocks:** unattended GitHub work (ship/PR flows), idle autonomy without a human watching

## Problem

Autonomy today is a switch, not a ladder. There are five booleans/strings
(`allowWrite`, `allowRebuild`, `confirm`, `dryRun`, `profile`) and they answer the wrong
question: they say *which tool family* may run, never *which action*. `apply_module_config` and
`gh pr merge` are both "write" — one is a config edit the human re-reads tomorrow, the other
publishes to a shared branch.

Worse, the fine-grained knobs that already exist do nothing. `schedules.<name>.allowWrite`,
`allowRebuild`, `dryRun` and `profile`
([options.nix:92-110](../../options.nix)) have no path into the process they are supposed to
govern: the generated unit hardcodes the environment and the `agent run` command line has no
permission flags at all. A host that sets `allowWrite = false` for one schedule and `true` for
another gets **identical** behaviour for both — and no error saying so.

Third: the git write chain (`ensure_branch` → `commit_all` → `push_branch` → `open_pull_request`
→ `merge_pull_request`) has no branch rules. Nothing stops a push to `main`, and `commit_all`
stages everything with `git add -A`
([workflow_execute.py:326](../../python/ncc_assistant/workflow_execute.py)).

## Measured today

| Question | Answer today | Evidence |
|----------|--------------|----------|
| Can a schedule set its own rights? | Options exist, nothing reads them | `options.nix:92`, `:97`, `:102`, `:107` |
| Unit environment | Hardcoded `AGENT_CONFIRM="writes"`, `AGENT_ALLOW_WRITE="0"`, `AGENT_ALLOW_REBUILD="0"` | `schedules.nix:107-116` |
| Unit command line | `agent run` + `--max-steps/--profile/--dry-run/--playbook/--goal` only | `schedules.nix:57-70` |
| CLI permission flags | none on `agent run` (`--goal/--max-steps/--dry-run/--profile/--playbook/--harness/--verbose`) | `cli.py:1171-1189` |
| Wrapper environment | Exports `AGENT_ALLOW_WRITE/REBUILD/CONFIRM/DRY_RUN` **unconditionally** from global `cfg.agent.*`, then the same wrapper inline-exports it into every entry point (`EnvironmentScript`-style), overwriting any unit value | `package.nix:187-192`, `:227-229` |
| `NCC_ASSISTANT_AGENT_*` vars | Read into `Settings`, **zero** consumers anywhere else in the package | `config.py:228-232` |
| Enforcement point | Risk-based only: `risk in ("write","rebuild") and not writes_enabled`, `risk == "rebuild" and not allow_rebuild`, confirm gate | `runtime.py:1010`, `:1020`, `:1040` |
| Kill switch / presence | Work, and are the only real autonomy brakes | `runtime.py:829`, `idle.py:152-162` |
| Branch protection | None. `push_branch` pushes the checked-out branch to `origin`, any name | `workflow_execute.py:344-363` |
| Staging | `git add -A` (everything dirty, including an untracked `.env`) | `workflow_execute.py:326` |
| Merge guard | `--confirm CONFIRM` for human CLI calls; no base-branch check, no force-push ban | `workflow_execute.py:413-426`, `cli.py:1636` |
| Actor on approvals | `PendingDecision` has job/session ids, no actor/schedule identity; audit logs tool calls, not permission decisions | `notifications.py:62-73`, `audit.py:42-66` |
| Triggers | clock only (`OnCalendar`); `scheduleKind: "poll"` exists in 6 templates with no consumer; idle fires only from Companion | `schedules.nix:129`, `templates/workflows/*.json`, `companion.py:1998` |

**Consequence:** per-schedule permissions are not "broken in a corner case", they have no
transport. Fixing the transport is a precondition for the ladder — otherwise the ladder is
configured in Nix and ignored in code, which is the current state in a nicer dress.

## Goals

1. **Grants reach the process.** A schedule's grant shows up in the unit's argv, and
   `ncc ai agent run` accepts the same grant by hand.
2. **Host = ceiling, schedule = step.** Anything below the host config may only *narrow*
   permissions; asking for more than the ceiling fails loudly instead of silently degrading.
3. **Actions, not tools.** The ladder names what may happen to the repo and to the system;
   tools map onto steps, so a new tool cannot smuggle in a new capability.
4. **Non-negotiable floor.** force-push, `--no-verify`, and pushing a protected branch are
   refused by code with no option that re-enables them.
5. **Budgets, not vibes.** Runs/day, PRs/day, diff size — exceeded means skipped and audited,
   before any LLM call.
6. **Every permission decision is auditable** with actor (schedule id, companion, cli) so
   "why did this merge?" has an answer the next morning.

## Non-goals

- No new approval UI — phase 22's notification/chip path stays; this phase decides *whether* a
  prompt is needed, not how it looks.
- No OS-level sandbox (namespaces, seccomp). The floor here is application-level refusal plus
  the existing shell allowlist; a real sandbox is its own phase.
- No secrets manager, no per-repo tokens.
- No GitHub webhook receiver — PR-driven triggering is phase 40 territory (see Open decisions).

## Design

### 1. Transport first (P0, without it the rest is decoration)

Precedence, single rule: **most restrictive wins**, and the result may never exceed the host
ceiling:

```
CLI flag  >  unit env  >  host config (ceiling)  >  code default
                          ↑ nothing below may widen this
```

- `agent run` gains `--grant repo=<step>` / `--grant system=<step>` (and the inverse
  `--deny repo=merge`) plus `--dry-run` staying as-is. Flags map onto `AgentSettings`, which
  already feeds `resolve_profile(...)` overrides
  ([profiles.py:87-114](../../python/ncc_assistant/profiles.py)) — the override parameters
  exist, they are just never passed anything but `None` outside the GUI
  ([agent.py:416-426](../../python/ncc_assistant/agent.py)).
- Unit: `mkAgentExec` ([schedules.nix:52-70](../../schedules.nix)) appends the grant flags to
  `agentArgs`; the hardcoded `environment` block (`:107-116`) becomes derived from the schedule
  values with today's values as default.
- `envExports` ([package.nix:187-192](../../package.nix)) must export defaults, not verdicts:
  emit `export AGENT_ALLOW_WRITE="${AGENT_ALLOW_WRITE:-<nix default>}"` so a unit-provided value
  survives the wrapper (`:227-229` inlines the same string into every entry point today).
- Asking above the ceiling is an error, not a downgrade:
  `refusing schedule 'nightly-ship': grant repo=merge exceeds agent.allowWrite=false`.
- `NCC_ASSISTANT_AGENT_*` (`config.py:228-232`) gets real consumers or is removed — a settings
  variable nobody reads is a false control surface.

### 2. Two axes, explicit steps

Repo axis (what happens to *someone's repository*) and system axis (what happens to *this
machine*). One ladder each; a grant names one step per axis and implies every lower step.

| Repo step | Unlocks | Risk |
|-----------|---------|------|
| `observe` | `repo_status`, `github_state`, read-only facts (phase 38) | read |
| `propose` | `propose_config_patch`, plan/task writes in the local queue | read |
| `commit` | `git add <paths>` + commit on `ncc/*` only | write-local |
| `push` | push `ncc/*` to origin | network-write |
| `pr` | `gh pr create`, PR body edits | network-write |
| `merge` | `gh pr merge` on an unprotected base | network-write, shared |
| `release` | version bump + tag + `gh release` | always human confirm |

| System step | Unlocks |
|-------------|---------|
| `none` | nothing (read) |
| `config-write` | `apply_module_config` (confirm per `agent.confirm`) |
| `rebuild` | `apply_system` (ceiling `allowRebuild` + `forceDangerous` as today) |

Nix shape, additive — old fields keep working and are mapped to steps so no host breaks:

```nix
agent.schedules.nightly-ship = {
  enable = true;
  onCalendar = "*-*-* 02:30:00";
  playbook = "autonomous-agent-ship";
  permissions = {
    repo = "pr";            # default: derived from profile/allowWrite today
    system = "none";        # default: derived from allowRebuild
    budget = { maxRunsPerDay = 1; maxPrsPerDay = 3; maxDiffLines = 800; };
  };
};
```

Mapping for compatibility: `profile = "read-only"` → `repo=observe, system=none`;
`config-writer` → `repo=propose, system=config-write`; `ops` → `repo=propose, system=rebuild`.
`allowWrite`/`allowRebuild`/`dryRun` remain the ceiling knobs; `permissions.*` only narrows.
`agent.schedules.<n>.allowWrite` etc. become deprecated aliases that emit a warning when
combined with `permissions` (so the two never disagree silently).

### 3. One evaluator, no direct reads

`permissions.evaluate(axis, action, context) -> allowed | needs_confirm | denied` is the single
place that decides. Today `runtime.py` reads `settings.writes_enabled` / `allow_rebuild` at
seven sites (`:455`, `:523`, `:761`, `:1011`, `:1020`, `:1218`, `:1474`) and
`workflow_execute.py` reads none of them — a CLI `workflow merge` bypasses the agent's entire
permission model. Both must call the evaluator, and the tool risk map becomes derived
(`MUTATING_TOOLS` stays as the floor for tool classification, not as the grant model).

### 4. Git rules that cannot be configured away

Refused in code, no option, tested by red-team (`red_team.py` gains cases):

- `push --force` / `--force-with-lease` / `+refspec` in any argument position;
- `commit --no-verify`, `--no-gpg-sign`, `-c commit.gpgsign=false`;
- push or merge where the target branch matches a protected pattern — default
  `["main", "master"]`, extended by what GitHub reports as protected (phase 38's
  `github.protectedBranches`, TTL-cached). Agent branches stay `ncc/workflow-*`
  (`_SAFE_BRANCH`, `workflow_execute.py:23`) and that prefix becomes a precondition for
  `commit`/`push`, checked in the helper rather than only in `ensure_branch`;
- `git add -A` / `git add .`: replaced by an explicit pathset (`commit` requires the file list
  the run actually touched) and a deny list for secret-shaped paths (`.env*`, `*.pem`,
  `*credentials*`, `secrets.json`) that refuses to stage regardless of grant.

Every one of these returns a distinct, greppable error (`denied_force_push`) so the audit shows
an attempted escalation rather than a generic failure.

### 5. Budget

Counters live next to the jobs store (`state.json`-style, pruned by phase 37's `maintenance`),
checked **before** the LLM call so a budget breach costs nothing:

| Counter | Default | Breach |
|---------|---------|--------|
| runs/day per schedule | from `budget.maxRunsPerDay`, else unlimited | skip with `reason: budget_runs` |
| PRs/day per repo | 3 | drop to `push`, report "pr held by budget" |
| diff lines per run | 800 | commit refused, work stays local, task stays open |
| open agent PRs per repo | 5 | no new branch/PR until one closes |

Budget is not a safety claim — it bounds blast radius while the ladder is still being trusted.

### 6. Audit and actor

New events in `audit.jsonl` (already `0600`, already pruned by `maintenance run`):
`grant_evaluated` (axis, action, result, actor, source of the narrowing), `git_action`
(action, repo id, branch, commit, result), `budget_exceeded`, `floor_denied`.
`PendingDecision` gains `actor` (`schedule:<id>` / `companion` / `cli` / `job:<id>`) and
`grant` so an approval can be read back as "nightly-ship asked to merge PR #12, allowed 41 s
later" — today's record cannot answer that.

### 7. Triggers beyond the clock

Small, but the ladder is pointless if the agent can only wake at a fixed time:

- **`poll`**: give `scheduleKind: "poll"` its consumer — `OnUnitActiveSec=`/`OnBootSec=` timer
  plus a state hash so a run only starts when something actually changed (repo fact hash from
  phase 38). Without a change, exit before the LLM call. Done: a schedule now declares
  `trigger = "poll"` with `pollInterval` + `pollWatch`, the timer is monotonic (`OnBootSec` +
  `OnUnitActiveSec`, no `OnCalendar`, no `Persistent` — a poll has no missed slot to catch up),
  and `poll_guard.py` answers one question before the budget counters, the lock and the model:
  *is this state one I already acted on?* A watch entry is `workspace:<id>` (HEAD + branch +
  porcelain state, so an uncommitted edit counts) or `file:/abs/path`; the baseline is written
  only by a **finished** run, so a crash retries the same state. Absence is a state (the day a
  file appears is not skipped); **unknown is never reported as unchanged** — an unresolvable
  watch denies loudly and records nothing, because a gate that guesses "unchanged" once makes
  the schedule quietly never run again.
- **Event**: `onUnitInactiveSec` chaining — schedule B runs only after schedule A ended
  `completed`, so `audit → ship` becomes a declared chain instead of two timers guessed apart.
- **Idle**: keep `idle.py` as the only opportunistic trigger and let it inherit the *lowest*
  grant of the day, never a schedule's higher one. Done: the sweep takes
  `permissions.lowest_grant_today()` on each axis and exports it for the run it starts, restoring
  the previous grant afterwards because the companion outlives the sweep.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| L1 | `agent run --grant repo=…/system=…` + `AgentSettings` plumbing | P0 |
| L2 | Unit passes the grant (argv) and stops being overwritten by the wrapper | P0 |
| L3 | Ceiling enforcement + loud refusal above ceiling | P0 |
| L4 | `permissions.evaluate()` as single decision point; `runtime.py` + `workflow_execute.py` call it | P0 |
| L5 | Repo/system step model + Nix schema (`permissions.*`), old fields mapped | P0 |
| L6 | Non-negotiable floor: force-push, `--no-verify`, protected branch, `git add -A`/secret paths | P0 |
| L7 | Red-team cases for every floor rule (no option can re-enable) | P0 |
| L8 | Budget counters, checked before the LLM call | P1 |
| L9 | `grant_evaluated` / `git_action` / `budget_exceeded` / `floor_denied` audit events | P1 |
| L10 | `PendingDecision.actor` + `grant`, surfaced in `approve list` | P1 |
| L11 | `poll` trigger with change-hash (`scheduleKind` finally honoured) | P1 |
| L12 | Scheduled-chain trigger (`after = "nightly-audit"`) | P2 |
| L13 | Per-repo `permissions.json` that may only lower the ceiling | P2 |
| L14 | Deprecation warnings where `profile`/`allowWrite` and `permissions` disagree | P2 |

## Delivered (measured against the tree)

| ID | State | Where |
|----|-------|-------|
| L1 | done | `agent run --grant repo=… --grant system=…` → `resolve_run_grant` → `set_process_grant` |
| L2 | done | `mkAgentExec` appends `--grant` to argv; unit sets `NCC_ASSISTANT_GRANT_REPO_CEILING` + `NCC_ASSISTANT_ACTOR`; `package.nix` `narrowBoolExport` defaults instead of verdicts |
| L3 | done | `Agent.run` refuses before any LLM call and audits `grant_denied`; `grantConflicts`/`budgetConflicts` warn at eval |
| L4 | done | `decide_system` weighs the host ceiling first and the run's grant second, so one answer covers every route; `system_flags` narrows the advertised catalog the same way; `runtime._may` is the only reader of `writes_enabled`/`allow_rebuild` (`:442`, `:538`, `:1515` pass them as arguments, none branch). The `call()` dispatcher stays grant-only by measurement: `_tool_is_mutating` also fires on `domain.*` mutating *verbs*, so adding the ceiling there would newly block `risk = "read"` tools under `allowWrite = false` |
| L5 | done | `grants.repoCeiling`/`grants.budget`, per-schedule `permissions.{repo,system,budget}` |
| L6 | done | `check_git_argv` + `check_branch` + `check_shell_command` + `_merge_base_floor`; eight `denied_*` codes plus fail-closed `merge_base_unknown` — L13 added the ninth, `denied_repo_ceiling_path` |
| L7 | done (except merge) | `red_team.py` probes every `denied_*` code and fails CI on an uncovered new one; the merge-base floor is covered by `tests/ncc-assistant/test_merge_protected_base_v1.py`, not by `red_team.py` — reading a PR base needs a network, which the probe cannot fake purely |
| L8 | done | `budgets.py`; counters arrive as `NCC_ASSISTANT_BUDGET_*`, checked before the LLM call |
| L9 | done | `permissions._record` is the ladder's only audit writer and `evaluate`/`decide_system` call it, so no decision route can omit the line: `grant_evaluated` carries the axis, the held and needed step, the refusal code, the actor and the tool. The run-level line was renamed `grant_resolved` — "what the run was handed" and "what it asked to do" are different questions. Two paths deliberately stay silent: `system_flags` asks `_cover` (an unrecorded verdict) so a catalog refresh cannot bury the real decisions, and the `call()` dispatcher pre-checks with `peek_system` then `record_denial`, so a gated call writes one line rather than two. The dispatcher's old bare `deny` line for the ladder is gone; the kill-switch keeps its own |
| L10 | done | `PendingDecision.actor` + grant, shown by `approve list` as `asked by <actor> · <grant>` |
| L11 | done | `trigger`/`pollInterval`/`pollWatch` on a schedule; `mkScheduleTimer` emits `OnBootSec`+`OnUnitActiveSec` for a poll and leaves a calendar timer exactly as it was; the unit carries `NCC_ASSISTANT_POLL_SCHEDULE/_INTERVAL/_WATCH` so two polls never share one stored hash. `poll_guard.py` gates before budget/lock/job store/LLM (`poll_unchanged`, `poll_state_unknown`), spends the baseline only on `job_finished`, and the idle sweep hands each candidate its own poll identity (`idle._run_scoped_poll`). Display stopped lying: `onCalendar` is nullable, `ScheduleSpec.frequency` says `every 15min` for a poll, `nix_snippet` emits the poll attrs, and `permissions show` carries the run's poll identity, its watch
list and when it last acted — a schedule that skips 96 ticks a day looks broken unless the tool says
otherwise. Evaluation refuses the shapes that could only burn a model every interval — poll without interval or watch, unusable watch entries, a non-agent poll, poll+`onCalendar`, calendar+`pollWatch`, calendar without `onCalendar`. `tests/ncc-assistant/test_poll_trigger_v1.py` |
| L12 | open | no `after` option on a schedule |
| L13 | done | `.ncc/permissions.json` — `{"version": 1, "repo": "<step>"}`, read out of **HEAD** (`ls-tree` + `git show`), never the worktree: the working tree is precisely what a bounded run may write, so deleting, widening or corrupting the file on disk moves nothing. Strict grammar (`repo` only, one version) because the system axis is the host's and a repo that speaks for it is refused, not ignored. Lower-only by construction: `_cover` takes the *lower* of held step and file step, so a file above the run's step cannot widen anything and is audited `ceiling_ignored=<step>` — the owner reads which answer was narrower instead of guessing. Anything unreadable **floors** the axis (`repo_ceiling_invalid`/`repo_ceiling_unknown`, not `denied_`-prefixed: nothing was escalated, the file just cannot be trusted) and the refusal reaches the audit as `ceiling=<code>`. Escalation-by-commit is closed by a floor on the whole `.ncc/` directory — `denied_repo_ceiling_path` on argv (`add`/`commit`, and `rm`/`mv` in either direction, since a staged deletion drops the ceiling the moment anyone commits the index), on the `commit_all` pathset, and on the human CLI path: a repository may lower its ladder, a run may not raise it. `permissions show` reports the narrowing from the same HEAD read (`repoFile` in `--json`). `tests/ncc-assistant/test_repo_permissions_v1.py` |
| L14 | done | Three disagreements between the old knobs and `permissions.*` now warn at evaluation. **Profile vs grant:** a profile is what *opens* the write/rebuild tools — `resolve_profile` keeps its built-in flags unless the grant lowers them and nothing raises them (an agent run hands it no override), so a schedule whose grant carries `system` above its profile's reach holds a step the ladder approves and the tool catalog cannot perform; every such write dies in the profile check instead of the audit trail. `profileSystemReach` compares the two, aliases included (`cautious`/`autonomous`, because `profiles.py` resolves them — deliberately *not* merged into `profileStepMap`, which derives the steps a unit is handed and must never widen them). An unknown name counts as reaching nothing, matching the read-only fallback, so a typo is loud. **Host pair vs agent pair:** `hostCeiling.system` was the agent pair alone, so evaluation blessed a unit that then refused at the first write; it is now `minStep` of the host pair and the agent pair, mirroring `resolve_run_grant`, and `ceilingInversions` names the case where `agent.allowWrite`/`agent.allowRebuild = true` cannot open what `allowWrite`/`allowRebuild = false` closed. The min only ever narrows *derived* steps — an explicit `permissions.*` stays as asked so the run refuses loudly rather than quietly doing less. **Display:** `perms.repo or "-"` did not cover a present-but-null option (`or` guards a *missing* attribute only), so the above-ceiling message aborted evaluation with "cannot coerce null to a string" — the config error replacing the message meant to explain it. `shownStep` renders both steps. |

Still open from the design, beyond L12:
`NCC_ASSISTANT_AGENT_CONFIRM/_DRY_RUN/_PROFILE` are
still read into `Settings` and used by nobody (§1 said "real consumers or removed") — what the
runtime acts on is the unsuffixed `AGENT_CONFIRM`/`AGENT_DRY_RUN`/`AGENT_PROFILE`
(`runtime.py:903`, `:1425`), so those three fields are a second, inert copy of the same setting.
`NCC_ASSISTANT_AGENT_ALLOW_WRITE/_REBUILD` got their consumer: `config` reads them tri-state
(unset ≠ `0`) and `resolve_run_grant` folds them into the system ceiling through
`permissions.agent_axis_ceiling`, so the agent pair can only ever lower the host pair — the
operator wiring decision for this phase. Idle inherits the day's floor (§7): the sweep takes
`permissions.lowest_grant_today()` per axis over the UTC day's `grant_resolved` lines and runs as
actor `idle`, so an opportunistic run never outranks the narrowest grant already granted today.

## Tests

- **transport**: eval'd unit contains `--grant repo=pr`; with a schedule grant and a different
  global `cfg.agent.allowWrite`, the built wrapper's default does not win (string-assert on the
  generated `envExports`, plus one CLI test that an explicit env var beats the default).
- **ceiling**: `allowWrite = false` + `--grant repo=commit` → refusal mentioning both values,
  exit non-zero, no LLM call.
- **regression (must stay closed)**: no schedule grant, default config → effective rights equal
  today's (`repo=observe`, `system=none`). This is the test that keeps the transport fix from
  silently widening anyone's agent.
- **ladder**: `repo=propose` refuses `commit`/`push`/`merge` with distinct reasons; `repo=pr`
  allows `push`; `merge` still needs confirm at every step.
- **floor**: force-push / `--no-verify` / push to `main` refused at `repo=release`; no Nix
  option changes that (assert the option set does not contain an override).
- **staging**: dirty `.env` + `commit` → nothing staged, `denied_secret_path`.
- **budget**: second run over `maxRunsPerDay` returns `skipped: budget_runs` and writes no job;
  oversized diff refuses commit and leaves the task open.
- **poll**: the gate is inert without a poll unit; first tick acts, the next does not, an edit does;
  absence is a state; a corrupt baseline is "no baseline" rather than a blank one; an unresolvable
  watch denies with `poll_state_unknown` and records nothing; an unchanged tick never reaches the
  budget counters, the lock or the job store; only `job_finished` spends the baseline; the idle sweep
  hands each candidate its own poll identity and leaves none behind. Nix side: real evaluation of the
  module — a poll timer is monotonic with no `OnCalendar`/`Persistent`, a calendar timer is unchanged,
  each poll unit carries its own id, and every trigger shape that could only burn a model fails an
  assertion. `tests/ncc-assistant/test_poll_trigger_v1.py`
- **audit**: each decision writes exactly one event with actor and reason — the line names the axis, the
  held and needed step and the code; a catalog refresh writes none; a dispatcher-gated call writes one
  line, not two. `tests/ncc-assistant/test_permission_audit_v1.py`
- **audit stays off the operator**: an emitter inside the evaluator writes wherever the process resolves
  its config home, and `patch.dict(..., clear=True)` deletes the session's throwaway `XDG_CONFIG_HOME`, so
  `conftest.py` fails any test whose audit line lands in the real `~/.config/ncc-assistant` — measured by
  the live log's sha256 being identical across a full suite run.
- **workflow_execute CLI**: `workflow merge` without the grant is denied (closes the bypass).
- **single decision point**: a write called *without* `call()` — the MCP server and diff-apply route —
  is still denied when the grant is narrower than the ceiling, and the host's own refusal keeps
  `host_writes_disabled` / `host_rebuild_disabled` instead of borrowing `grant_insufficient`; with no
  grant the ceiling answers exactly as before, and a `system=none` run is not shown the write tools.
  `tests/ncc-assistant/test_single_decision_point_v1.py`
- **eval warnings**: `schedules.nix` is evaluated for real (module called with the flake's own
  argument shape, deferred `mkIf`/`mkMerge` records flattened) — a grant above its profile's reach
  warns, a profile that reaches it stays silent, `cautious`/`autonomous` resolve instead of reading
  as unknown, an unknown name warns, both knob inversions warn, and a **derived** grant exports
  `AGENT_ALLOW_WRITE=0` on a host whose pair is closed while an explicit ask keeps `1` so the run
  refuses loudly. The stub schedule carries options.nix's submodule defaults, because a bare attrs
  stub cannot express present-but-null — the shape that made the above-ceiling message abort
  evaluation. The default host must produce no warnings at all: that assertion is what keeps the new
  `minStep` from turning every existing host into a wall of text.
  `tests/ncc-assistant/test_schedule_grant_ceiling_v1.py`

## Risks

- **Two sources of truth** (`profile` vs `permissions`). Mitigation: one evaluator, `profile`
  only a mapping, L14 warns on disagreement.
- **The transport fix itself widens rights.** It changes who wins when values conflict — the
  regression test above is the guard, and defaults are chosen to reproduce today's behaviour.
- **Confirm fatigue** at `merge` → the human approves anything. Mitigation: `merge` stays
  human-confirm at every step, `release` always, and budgets keep the number of prompts low.
- **Config as policy** invites rule sprawl; the floor is deliberately not expressible in Nix so
  a typo cannot open it.
- **Poll loops** can burn tokens and GitHub quota; change-hash + pre-LLM budget check +
  phase 38's rate-limit floor are the brakes.

## Open decisions

1. Is `merge` ever unattended? Recommendation: not in the first 30 days of the ladder running —
   require confirm, then decide from `grant_evaluated` data.
2. Grant lifetime: per run (recommendation) or "valid for the day" — the second is friendlier
   and much harder to reason about after the fact.
3. Should the ladder live in the repo (`.ncc/permissions.json`, lower-only, L13) so a repo can
   opt down without a host rebuild? **Decided: yes, and only ever down.** It is read from `HEAD`
   so the file a run is allowed to write cannot be the file that bounds it, the grammar carries
   the repo axis alone so a repository cannot speak for the machine, and the whole `.ncc/`
   directory is off-limits to staging in both directions — the commit that would relax a
   narrowing is refused exactly like the commit that would introduce one. A repo that ships a
   broken file gets the loud answer (`ceiling=repo_ceiling_invalid`), never the absent one.
4. Does a PR-merge trigger belong here (webhook/poll of "PR ready") or in a later phase with
   real event sources?
