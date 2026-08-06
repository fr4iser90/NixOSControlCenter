# Phase 2 — Agent mode

**Status:** planned  
**Parent:** [ROADMAP.md](../ROADMAP.md)  
**Depends on:** phase 1 (registry) strongly recommended; can prototype on builtins only  
**Unblocks:** phase 3 (jobs), phase 4 (schedules)

## Problem

Chat is interactive and open-ended. Users also want: “do this task” with a
clear stop condition, budget, and artifact — including later from cron.

## Goals

1. **Agent runner** that takes a goal string, uses the tool registry, loops until
   done / budget / cancel.
2. CLI: `ncc ai agent run --goal '…'`.
3. GUI: Agent section or mode (goal field, live trace, Stop).
4. Explicit **agent policy** separate from casual chat (`agent.allowWrite`, etc.).

## Non-goals

- Fully autonomous system administration without budgets.
- Multi-agent swarms / sub-agent trees (single agent loop first).
- Replacing chat (chat stays default for exploration).

## Features

| ID | Feature | Priority |
|----|---------|----------|
| A1 | `AgentRunner` over `ChatSession` / shared tool loop | P0 |
| A2 | Goal + system prompt variant (“you are an NCC agent…”) | P0 |
| A3 | Budgets: `maxSteps`, optional `maxTokens`, wall-clock timeout | P0 |
| A4 | Stop / cancel (reuse cancel event) | P0 |
| A5 | CLI `ncc ai agent run` (+ `--dry-run` later in phase 6) | P0 |
| A6 | GUI Agent panel: goal, Run, Stop, streaming tool trace | P0 |
| A7 | Policy: `agent.allowWrite` / `agent.allowRebuild` (default false) | P0 |
| A8 | Done detection: model signals finish **or** explicit `agent_finish` tool | P1 |
| A9 | Tool allowlist/denylist per run | P1 |
| A10 | Emit structured job result for phase 3 | P0 |
| A11 | Pluggable decision hook (GUI dialog **or** system notification — phase 7) | P0 |
| A12 | Respect presence `paused` before mutating tools / starting work | P0 |

## CLI sketch

```bash
ncc ai agent run --goal "List disabled specialized modules and summarize risks"
ncc ai agent run --goal "…" --max-steps 20 --model '…'
ncc ai agent run --goal "…" --allow-write   # only if module policy allows
```

## Nix options (draft)

```nix
agent = {
  enable = true;              # install agent CLI/units hooks
  maxSteps = 24;
  timeoutSec = 1800;
  allowWrite = false;
  allowRebuild = false;
  confirm = "writes";         # always | writes | never (phase 7)
  # toolAllowlist = null;     # null = all enabled registry tools except denied
  # toolDenylist = [ "apply_system" ];
};
```

## Loop (draft)

1. Seed messages: system (agent) + user (goal).
2. For step in 1..maxSteps:
   - LLM (+ tools from registry filtered by policy).
   - Stream deltas to UI/job log.
   - Execute tool calls (confirm hook if interactive; policy if headless).
   - If finish tool / model says done → success.
3. On cancel / timeout / step limit → failed/partial with reason.

## Headless vs interactive

| Mode | Confirm writes | Auth |
|------|----------------|------|
| GUI agent | In-app dialog if focused; else **system notification** (phase 7) | cached / prompt |
| CLI TTY | prompt or refuse | cached / prompt |
| Cron (phase 4) | Notification and/or approval queue (phase 6–7); never silent write by default | credentials file / env required |

Presence `paused` (“playing / DND”) blocks new mutating work in all modes — see [07-notifications-and-presence.md](./07-notifications-and-presence.md).

## Acceptance criteria

- [ ] Agent completes a read-only goal using builtins without GUI.
- [ ] Write tools blocked when `agent.allowWrite = false` even if chat `allowWrite = true`.
- [ ] Stop cancels mid-flight.
- [ ] Run produces a job id / folder consumable by phase 3.

## Test plan

- Read-only goal against fake LLM or recorded fixtures.
- Policy matrix: write allowed/denied.
- Cancel during tool execution.
