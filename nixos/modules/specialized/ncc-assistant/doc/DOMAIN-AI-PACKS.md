# Domain AI packs (`ai/` per module)

**SSOT** for how modules expose deterministic tools + short docs to the NCC Assistant.

## Layout

```text
<module>/
  ai/
    manifest.nix       # domain id, enable, description
    tools/*.json       # one tool per file
    docs/*.md          # short operator/AI guidance
```

Mirrors `ui/gui/` and `commands.nix`: the **module owns** the pack; **ncc-assistant aggregates** at build time.

## Manifest

```nix
{
  domain = "user";           # CLI domain (ncc user …)
  enable = true;
  description = "User accounts and roles";
}
```

## Tool JSON

| Field | Required | Meaning |
|-------|----------|---------|
| `name` | yes | Stable id, prefer `domain.<domain>.<verb>` |
| `description` | yes | Shown to the LLM |
| `inputSchema` | yes | JSON Schema for function-calling args |
| `argv` | yes | Argv template (list of strings); `{{arg}}` → substituted; **no shell** |
| `risk` | yes | `read` \| `write` \| `rebuild` |
| `permission` | yes | NCC capability string (see user `api.nix`), e.g. `user.create` |
| `confirm` | no | If true, write tools ask the user (GUI/notify) before run |

Example:

```json
{
  "name": "domain.user.create",
  "description": "Create a user account in systemConfig (no rebuild).",
  "risk": "write",
  "permission": "user.create",
  "confirm": true,
  "inputSchema": {
    "type": "object",
    "properties": {
      "name": { "type": "string" },
      "role": { "type": "string", "enum": ["guest", "virtualization", "restricted-admin", "admin"] }
    },
    "required": ["name", "role"]
  },
  "argv": ["ncc", "user", "create", "{{name}}", "--role", "{{role}}"]
}
```

## Permission layers (no escalation by prompt)

1. **Visibility** — Tool is omitted from the LLM tool list unless the **invoker’s NCC role** has `permission` (same wildcards as `core/base/user/api.nix`).
2. **Assistant policy** — `allowWrite` / `agent.allowWrite` / security **profile** (`read-only` blocks `risk=write|rebuild`).
3. **CLI / ncc-priv** — Actual mutations still go through `ncc …` → `ncc-priv` (e.g. guest cannot create; restricted-admin cannot assign `admin`).

The model never gets a free shell for domain work. Args only fill `{{placeholders}}` in a fixed argv.

## Docs

Short markdown under `ai/docs/` is copied into the assistant knowledge tree (`knowledge/domains/ai-<domain>.md`). Describe when to use which tool and hard limits (roles, no rebuild unless intended).

## Argv extras

| Token | Meaning |
|-------|---------|
| `{{key}}` | Required value |
| `{{key?}}` | Optional; omit token (and preceding `--flag` pair) if unset |
| `environment={{environment?}}` | Optional inline; omit whole token if unset |
| `{{flag:system}}` | If arg `system` is true → emit `--system`; else omit |

## Reference packs

`user`, `desktop`, `packages`, `modules` (module-manager).
