# GitHub Agent (SSOT plan)

**Status: done.** All checklist items exist; `tests/run-gates.sh` exited 0
with Companion **GitHub** rail live. Name remains **GitHub Agent** (not
“Portfolio Agent”).

**Name:** GitHub Agent (not “Portfolio Agent”).  
**Scope:** one plan for this goal. 28/34/37/38/39 are libraries this wires.

**Supersedes:** chat framing that called this a “portfolio” agent / “COMPLETE” title.  
**Linked from:** `doc/surfaces.md`, `doc/usage.md`, Companion rail **GitHub**.

**Shipped:** operator facts, snapshot, orchestrator, rights prefs, catalog
`github-agent`, CLI, Companion PANEL_GITHUB, tests, docs — gates green.

---

## Start (target UI)

Companion → rail **GitHub** → **Start agent**

## Run (orchestrator)

1. Readiness if needed (scan, token, MCP, bins).
2. Operator facts (country=DE → legal gaps elevated).
3. Fleet lifecycle → active / once / later / archive-candidate.
4. Archive: on board, no auto-writes.
5. Audit each non-archive workspace.
6. Extract Daily tasks (`gap:<id>`).
7. Drift report + optional GitHub digest.
8. Write `github-agent/snapshot.json` + update `daily.json`.
9. Job + `audit.jsonl` always.
10. Writes only under rights + grant + confirm.
11. Start opens chat session → analyze tool result → LLM narrates (agent works).

## Storage (`~/.config/ncc-assistant/`)

| Path | Role |
|------|------|
| `workspaces.json` | git roots |
| `operator-facts.json` | country / legal defaults |
| `github-agent/snapshot.json` | board SSOT |
| `workflows/daily.json` | tasks / roadmap / digest |
| `jobs/` + `audit.jsonl` | tracking |
| `preferences.json` | rights |
| `secrets.json` / `mcp-servers.json` | token + MCP |

## Checklist

- [x] `core/store/operator_facts.py`
- [x] `core/store/github_agent_snapshot.py`
- [x] `core/workflows/github_agent.py`
- [x] `data/agents/github-agent.json`
- [x] CLI `ncc ai github-agent analyze|show|rights`
- [x] Companion `PANEL_GITHUB` (board + Start + Rights)
- [x] Reuse audit/fleet/plan/drift/readiness
- [x] Tests + `tests/run-gates.sh` exit 0
- [x] `surfaces.md` + `usage.md` updated

## Acceptance (all required)

1. Rail **GitHub** → Start agent opens chat + runs analyze then LLM.
2. Board shows projects: state, gaps, next job.
3. DE fact elevates missing impressum/privacy.
4. Archived visible, not auto-written.
5. Rights change confirm/write for later runs.
6. Job + audit for every run.
7. Gates green.
