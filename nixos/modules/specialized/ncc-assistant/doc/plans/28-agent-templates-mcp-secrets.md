# Phase 28 — Agent templates, workspaces, secrets, MCP bundles

Status: **implemented** (core surfaces; see roadmap)  
**Parent:** [roadmap.md](../roadmap.md)  
**Depends on:** playbooks (14), MCP marketplace (19), schedules (4), safe profiles (18)  
**Related:** auth / credentials cache, git MCP template

## Problem

Playbooks today are thin: title + goal + profile. Users want **OpenHands-style
templates** (e.g. *GitHub code review*, *AGENTS.md Maintainer*) that bundle:

- agent prompt / skill pack
- required **MCPs** (git, github, filesystem, …)
- **workspace / repo** roots (local git paths, not only remote)
- **named secrets** (GitHub token, …) — never in `systemConfig`
- schedule / trigger fields (frequency, timezone, labels, …)
- clear **connection status** (“GitHub Connected” / “1 MCP to connect”)

Separately: when the LLM API key is stale, `/models` fails with 401 and the UI
used to keep showing an old model as if nothing was wrong (fixed in this phase’s
auth UX slice).

## Goals

1. **Agent template catalog** (built-in + user) with card UI + configure modal.
2. **Secrets store** (named secrets under `~/.config/ncc-assistant/secrets/`).
3. **Workspace registry** (local git roots + optional remote GitHub slug).
4. **MCP template install** wired to workspace path + secret refs (env injection).
5. **Skills / prompt packs** referenced by template id (reuse module `ai/` +
   `.agents/skills` patterns where useful).
6. Instantiated run = playbook/job with filled params + attached MCP + secrets.

## Non-goals (v1)

- Full GitHub App OAuth UI (PAT / token secret name is enough).
- Multi-tenant Agent Server cloud.
- Shipping proprietary OpenHands templates verbatim (inspire shape only).
- Putting tokens in Nix `systemConfig`.

## Architecture

```text
Template catalog (builtin JSON + ~/.config/.../agent-templates/)
        │
        ▼
 Configure modal ──► instance.json (params + secret refs + workspace ids)
        │
        ▼
 Runtime bind:
   - resolve secrets → env for MCP / tools
   - resolve workspaces → git/fs MCP args
   - merge skill/system prompt
   - start agent job / schedule / watchdog
```

### Layers (keep separate)

| Layer | What | Where |
|-------|------|--------|
| MCP template | How to start a server (`command`/`args`/`env`) | `templates/mcp/*.json` (exists) |
| Agent template | Workflow card + param schema + MCP deps + skill | `templates/agents/*.json` (**new**) |
| Skill / prompt | System + domain instructions | `prompts/` + optional skill md |
| Secret | Named opaque value | `~/.config/ncc-assistant/secrets.json` (0600) |
| Workspace | Local path (+ optional `github:owner/repo`) | `workspaces.json` |
| Instance | User filled params + schedule | `agent-instances/<id>.json` |

Playbooks remain the **execution** shape; agent templates **generate** a
playbook-like run (or a schedule binding) after the modal.

## Data shapes (draft)

### Agent template

```json
{
  "id": "github-code-review",
  "title": "GitHub code review",
  "category": "Code review",
  "description": "Review labelled PR heads; stop early on out-of-scope changes.",
  "skill": "skills/github-code-review.md",
  "profile": "read-only",
  "mcp": ["git", "github"],
  "requiresSecrets": ["github_token"],
  "params": [
    {
      "id": "checkFrequency",
      "label": "Check frequency",
      "type": "cronOrInterval",
      "required": true
    },
    {
      "id": "timezone",
      "label": "Timezone",
      "type": "timezone",
      "required": true,
      "default": "Europe/Berlin"
    },
    {
      "id": "repositories",
      "label": "Repositories",
      "type": "workspaceList",
      "required": true
    },
    {
      "id": "triggerLabel",
      "label": "Trigger label",
      "type": "string",
      "required": true,
      "default": "needs-review"
    },
    {
      "id": "requestedReviewer",
      "label": "Requested reviewer",
      "type": "string",
      "required": true
    },
    {
      "id": "reviewTone",
      "label": "Review tone",
      "type": "enum",
      "options": ["brief", "detailed", "nitpicky"],
      "default": "detailed"
    },
    {
      "id": "maintainers",
      "label": "Maintainers",
      "type": "stringList",
      "required": false
    },
    {
      "id": "githubTokenSecret",
      "label": "GitHub token secret",
      "type": "secretRef",
      "secretKind": "github_token",
      "required": true
    }
  ],
  "scheduleKind": "poll",
  "tags": ["github", "review"]
}
```

### NCC-first presets (ship early)

| id | Purpose |
|----|---------|
| `agents-md-maintainer` | Keep `AGENTS.md` current in configured git workspaces |
| `skills-maintainer` | Audit/update `.agents/skills/*/SKILL.md` |
| `ncc-module-review` | Review module PRs against discovery laws / gates |
| `local-git-status` | Periodic git status/diff summary for workspace roots |
| `github-code-review` | Labelled PR review (needs GitHub MCP + token secret) |

### Secrets

```json
{
  "secrets": {
    "github_token": {
      "name": "github_token",
      "label": "GitHub PAT",
      "created": "…",
      "updated": "…"
    }
  }
}
```

Values in a sibling file or same file under `value` — **0600**, never logged
(reuse `audit.redact_secrets`). GUI: Settings → Secrets (add / rotate / delete).
Templates only store **secret names**, not values.

Optional later: `apiKeyFile`-style path refs for sops/agenix on disk.

### Workspaces

```json
{
  "workspaces": [
    {
      "id": "ncc",
      "label": "NixOSControlCenter",
      "path": "/home/…/Git/NixOSControlCenter",
      "github": "owner/NixOSControlCenter"
    }
  ]
}
```

Git MCP install substitutes `--repository {{workspace.path}}`.

### MCP template extensions

Extend `templates/mcp/*.json`:

```json
{
  "name": "git",
  "args": ["mcp-server-git", "--repository", "{{workspace.path}}"],
  "envFromSecrets": {
    "GITHUB_PERSONAL_ACCESS_TOKEN": "{{secret.github_token}}"
  },
  "placeholders": ["workspace.path"]
}
```

New templates to add: `github` (official or community GitHub MCP), keep
`filesystem` / `fetch` / `git`.

## GUI

### Catalog tab (or Agent sub-view)

- Sections: **Proven workflows** / **Beta** / **Installed instances**
- Card: title, category, short description, badges:
  - `GitHub Connected` when required secret present + MCP installed
  - `N MCP to connect before launch` when deps missing
  - `Auth failed` when LLM provider key invalid (reuse models-fetch auth UX)

### Configure modal

Dynamic form from `params[]`:

- required fields marked
- `secretRef` → combo of saved secrets + “Add secret…”
- `workspaceList` → multi-select from workspace registry + “Add path…”
- schedule fields → write `schedules/` or watchdog when saved
- primary actions: **Save instance** / **Run once** / **Enable schedule**

### Settings

- **Secrets** panel
- **Workspaces** panel
- existing **Providers** (LLM keys) stay separate from agent secrets

## CLI sketch

```bash
ncc-assistant secrets list
ncc-assistant secrets set github_token
ncc-assistant workspaces add --path ~/Git/NixOSControlCenter --id ncc
ncc-assistant templates list
ncc-assistant templates show github-code-review
ncc-assistant templates instantiate github-code-review --from instance.json
ncc-assistant templates run <instance-id>
ncc-assistant mcp install github --secret github_token
```

## Auth / model list (done in this phase’s code slice)

- `GET /models` **401/403** → clear “Auth failed — update API key” status
- combo shows `(auth required — update API key)`, not a stale model id
- auth dialog offered immediately; after success, refetch models
- non-auth failures still allow configured-model fallback

## Implementation slices

| Slice | Work | Priority |
|-------|------|----------|
| A | Auth UX for `/models` (this PR) | P0 |
| B | Secrets store + Settings UI + CLI | P0 |
| C | Workspaces registry + CLI | P0 |
| D | MCP placeholders + `envFromSecrets` + github template | P0 |
| E | Agent template schema + 2–3 NCC presets + catalog UI | P0 |
| F | Configure modal + instance → playbook/schedule bind | P0 |
| G | GitHub code-review template (params as in product mock) | P1 |
| H | Skills maintainer + AGENTS.md maintainer prompts | P1 |
| I | Badge logic (“MCP to connect”, secret missing) | P1 |
| J | Eval cases for template instantiate (no network) | P2 |

## Acceptance criteria

- [x] Stale LLM key → UI says auth failed; no silent fake model list.
- [x] User can save a named secret and reference it from a template modal.
- [x] User can register a local git workspace and install git MCP against it.
- [x] At least one NCC preset (AGENTS.md or skills maintainer) runs as an agent job.
- [x] GitHub code-review template schema accepts frequency, timezone, repos,
      trigger label, reviewer, tone, maintainers, secret ref.
- [x] No secret values in `systemConfig` or transcripts (redacted).

## Test plan

- Unit: `list_models` 401 → `LLMError.is_auth`.
- Unit: secret round-trip + chmod 0600; redaction in audit.
- Unit: MCP arg/env placeholder expansion.
- Unit: template param validation (required / secretRef).
- GUI smoke: catalog loads; modal rejects missing required secret.
- Gate: `tests/run-gates.sh` after Python/Nix touches.
