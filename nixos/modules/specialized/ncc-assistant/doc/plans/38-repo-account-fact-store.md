# Phase 38 — Repo & account fact store (identity, not path)

**Status:** proposed
**Parent:** [roadmap.md](../roadmap.md)
**Depends on:** phase 37 (workspace workflow), phase 17 (agent memory), phase 19 (MCP marketplace)
**Unblocks:** phase 39 (permission ladder needs "which repo is this"), any GitHub-account autonomy

## Problem

The agent has no durable idea of what a repository *is*. Every run re-derives everything from
the filesystem, and what it derives is keyed by **path** — the one thing that changes when a
folder is renamed, moved to another disk, or mounted on another host. Task queues, MCP server
bindings, workflow progress and memory notes all hang off that path-shaped id, so a rename
silently orphans all of it.

Second problem: there is no Git or GitHub **tool**. `TOOL_DEFINITIONS`
([runtime.py:16](../../python/core/runtime/runtime.py)) ships 20 tools, none of them Git-aware.
The only GitHub access in the package is `_gh_json` ([workflows.py:193](../../python/core/workflows/workflows.py)),
a `gh` subprocess used to build a digest that is overwritten each refresh and never becomes a
task. So "check whether my repos are up to date" cannot be an agent step today; it is a report.

Third: installing an MCP server buys **zero tools**. The registry only registers tools declared
inline in `mcp-servers.json` — `tools = server_def.get("tools") or []`
([registry.py:221](../../python/core/runtime/registry.py)) — while `install_template` writes
`command/args/env/workspaceId` and no `tools`
([marketplace.py](../../python/core/catalogs/marketplace.py)). `McpClientPool.list_tools`
([mcp_client.py:147](../../python/core/runtime/mcp_client.py)) has no caller at all. Templates
asking for `mcp: [git, github]` therefore get nothing.

## Measured today

| Area | State | Evidence |
|------|-------|----------|
| Workspace record | `{id, label, path, github}` — no fingerprint, no default branch, no freshness | `workspaces.py:21-45` |
| Identity source | `slug_from_path` / `detect_github_slug` derive from the directory | `workspaces.py:48`, `:58` |
| Discovery | one-level scan, `is_git_repo` only | `workspaces.py:84` |
| Task record | `{id, title, body, status, priority, workspaceId, links, createdAt}` — no `updatedAt`, no source, no issue ref, no lease | `workflows.py:92-101` |
| GitHub | `gh` subprocess → digest text, never tasks; no REST client, no rate-limit handling | `workflows.py:193`, `:262`, `:275` |
| Git tools for the model | none | `runtime.py:16` |
| MCP tools after install | `tools` key never written, `list_tools` never called | `registry.py:221`, `mcp_client.py:147` |
| Memory scoping | `MemoryNote{id, content, tags, created_at, source, job_id, session_id}` — no repo entity | `memory.py:20-30` |
| Git operations | branch/rebase/validate/commit/push/PR/merge exist but are workflow-only, not tools | `workflow_execute.py:167-462` |

## Goals

1. **Identity = remote, not path.** A repo is `owner/name` from `origin`; the local path is an
   attribute of that identity, replaceable without losing history.
2. **One facts file per identity, with freshness.** Everything the agent knows about a repo is
   stored once, carries `measured_at`, and is re-measured only when stale.
3. **Facts are typed by source.** `measured` (a command ran and returned) vs `inferred` (a file
   exists, a heuristic fired). The prompt says which is which, so the model never presents a
   guess as a fact.
4. **Tasks, memory, and MCP bindings key off the identity**, so `workspaces rename` and `move`
   are supported operations that rewrite references instead of orphaning them.
5. **GitHub state becomes tasks**, not prose: failing CI, review requested, stale branch,
   behind-default become entries in the per-repo queue with a stable dedupe key.

## Non-goals

- No write operations to GitHub in this phase — read-only facts. Writes are phase 39's ladder.
- No multi-host merge server, no cloud sync, no cross-user sharing.
- No embedding/vector search; the store is a small JSON file the agent reads through tools.
- No background daemon. Measurement happens inside a run (or a schedule), never as a service.

## Design

### Identity

```
repo identity  = normalized origin remote  →  "owner/name"
                 (ssh and https forms of the same remote normalize to the same id)
local binding  = absolute path, may be absent (repo not cloned here)
```

Rules:
- `github` (existing field) already holds `owner/repo` when it could be detected; promote it to
  the primary key and require it for repos that have a remote.
- Repos without a remote keep a `local/<slug>` id plus a content fingerprint
  (`rev-parse HEAD` + first-commit hash) so a move can be re-recognised.
- Two workspaces pointing at the same remote are one identity with two bindings — that is the
  multi-host / worktree case, and it must not double-count ahead/behind.

### `repos.json` (v1, mode `0600`, same dir as `workspaces.json`)

```json
{
  "version": 1,
  "repos": {
    "fr4iser/NixOSControlCenter": {
      "id": "fr4iser/NixOSControlCenter",
      "bindings": [{ "path": "/home/fr4iser/Documents/Git/NixOSControlCenter", "host": "localhost", "lastSeenAt": "…" }],
      "defaultBranch": "main",
      "measured": {
        "head": "6ca20999",
        "branch": "main",
        "ahead": 0,
        "behind": 4,
        "dirty": false,
        "dirtyCount": 0,
        "worktrees": 1,
        "lastCommitAt": "…",
        "pristineRemoteRefs": true
      },
      "github": {
        "isFork": false,
        "defaultBranch": "main",
        "protectedBranches": ["main"],
        "openPrs": [{ "number": 12, "head": "ncc/workflow-…", "mergeable": true, "checks": "failure" }],
        "ci": { "head": "6ca20999", "status": "failure", "url": "…" },
        "rateLimitRemaining": 4311
      },
      "validation": { "commands": ["bash tests/run-gates.sh"], "source": "gate-file", "confidence": "measured" },
      "stack": ["nix", "python"],
      "inferred": { "hostOf": "self-hosted agent layer", "owners": ["fr4iser"] },
      "measuredAt": "…",
      "staleAfterSec": 86400
    }
  }
}
```

Freshness rules:
- `measuredAt` + `staleAfterSec` decide whether a run re-measures. Git working-tree facts
  (`dirty`, `ahead`, `behind`) are re-read **always** — they change under the agent's hands;
  only the expensive parts (`gh api` calls, CI, protection rules) honour the TTL.
- Any tool that returns repo facts labels each field group `measured` / `inferred` / `stale`.
- Failed measurement is stored as `{"error": "…", "attemptedAt": "…"}`, never as an empty value —
  "no CI" and "could not read CI" must not look the same.

### Entity scoping for memory

Add optional `repo: str | None` and `workspace: str | None` to `MemoryNote`
([memory.py:20](../../python/core/runtime/memory.py)). Notes without a repo stay global.
`memory.search` and `for_prompt` gain a `repo=` filter so a run about repo A stops injecting
advice about repo B. Existing `memory.jsonl` lines stay valid (missing field = global).

### Rename / move are first-class

`ncc ai workspaces rename ID --label …` and `… move ID --path …` must rewrite, in one
transaction:

| Reference | Where |
|-----------|-------|
| `workspaces.json` entry | `workspaces.py:136` `_save_raw` |
| MCP `workspaceId` bindings | `marketplace.py` installed entries |
| Task `workspaceId` | `workflows.py:97` |
| Workflow progress files | `paths.workflow_progress_file(workspace_id)` |
| `{{workspace.path}}` in already-installed args | installed `mcp-servers.json` (resolved values — must be re-expanded or rewritten literally) |

A rename that cannot rewrite everything rolls back. Half-rewritten references are the exact
failure this phase exists to remove. Note `mcp-servers.json` holds **resolved** paths (expanded
at install time, `marketplace.py:169-186`), so the rewriter must patch the expanded strings, not
just re-render a template.

### Tools the model gets (new `git` tool family, risk `read`)

| Tool | Returns |
|------|---------|
| `repo_list` | stored identities + binding state (missing path, dirty, behind) |
| `repo_status` | live working-tree facts for one repo (always re-measured) |
| `repo_scan` | discover repos under a parent, upsert identities, report new/moved/missing |
| `repo_facts` | stored record with `measured/inferred/stale` labels |
| `github_state` | open PRs, CI for HEAD, protection rules (TTL-cached `gh`/REST) |
| `github_tasks` | GitHub state converted into queue items with `sourceKey` for dedupe |

`MUTATING_TOOLS` stays untouched — all six are read-risk and available to `read-only`.

### GitHub transport

Wrap `gh` once (`_gh_json` today is fine as the transport) and add:
- one place that reads `X-RateLimit-Remaining` and refuses new calls below a floor, storing
  `rateLimitRemaining` so a schedule can see why nothing refreshed;
- `gh`-missing → `{ok: false, error: "gh not installed"}` instead of `None` (today a silent
  `None` collapses "no gh" and "empty answer");
- every GitHub-derived task carries `sourceKey = "gh:owner/repo:pr:12:review_requested"`, so a
  refresh adds new work and closes resolved work instead of wiping the queue.

## Features

| ID | Feature | Priority |
|----|---------|----------|
| R1 | `repos.json` store + schema (identity, bindings, measured/inferred, TTL) | P0 |
| R2 | Normalise remote → `owner/name`; detect two paths, one identity | P0 |
| R3 | `repo_scan` (discover + upsert + report moved/missing) | P0 |
| R4 | `repo_status` always-fresh working tree facts | P0 |
| R5 | `github_state` with TTL cache + rate-limit floor | P0 |
| R6 | GitHub → task conversion with stable `sourceKey` | P0 |
| R7 | Register the six read-only tools in `TOOL_DEFINITIONS` + registry risk map | P0 |
| R8 | `MemoryNote.repo` + scoping in `search` / `for_prompt` | P1 |
| R9 | `workspaces rename` / `move` with reference rewrite + rollback | P1 |
| R10 | `ncc ai repos list --json` / `repos show ID` / `repos scan PATH` | P1 |
| R11 | MCP client: call `list_tools` after install and persist the `tools` list | P1 |
| R12 | Report of "repos needing attention" as the digest's data source (replaces text-only digest) | P2 |
| R13 | Move `github_token` usage behind one client that never logs the token (audit already redacts) | P2 |

## Migration

- `workspaces.json` stays version 1 — additive only until rename/move lands, then bump to 2 with
  `migrations/` cleanup **only if** a host needs old records rewritten.
- `repos.json` is new: absence means "not scanned yet", which must not be reported as "no repos".
- `memory.jsonl` is append-only JSONL; new optional fields need no migration.

## Tests

- identity: ssh vs https remote normalise to one id; two paths one identity; no-remote repo gets
  a fingerprint id and survives a move.
- staleness: TTL hit does not call `gh` (assert the transport is not invoked); TTL miss does.
- error honesty: `gh` missing ⇒ `error` set and `github` absent, never `github: {}`.
- rename: task `workspaceId`, MCP binding and progress file all follow; failure mid-rewrite
  leaves the old state intact.
- `github_tasks`: same PR state twice does not duplicate; a resolved state closes the task.
- tools: all six appear in `openai_tools(allow_write=False)` and none is in `MUTATING_TOOLS`.

## Risks

- **Token scope.** The PAT in `mcp-servers.json` is already `0600`; a REST client must not widen
  what it can do. Read-only scopes stay a host decision, and phase 39 owns anything that writes.
- **Stale facts presented as truth.** Mitigated by mandatory labels plus always-fresh working tree.
- **Scan cost.** A deep scan of a large home directory is slow and can hit mounts; keep
  `max_depth` bounded and require an explicit parent path.

## Open decisions

1. Does `github_tasks` write into the same per-workspace `daily.json` queue, or a per-repo queue?
   (Today: one queue per workspace, `workflows.py:28/:69`.)
2. Rate-limit floor value, and whether hitting it should surface as a watchdog event.
3. Whether `repo_scan` may register new repos automatically or always needs confirmation.
