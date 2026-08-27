# Domain AI packs (`ai/` + `doc/ai-*.md`)

**SSOT** for how modules expose deterministic tools + short docs to the NCC Assistant.

## Layout

```text
<module>/
  doc/
    ai-overview.md     # (optional) short guidance for the LLM — ONE docs home
    usage.md           # human docs (same folder)
    cli.md
  ai/
    manifest.nix       # domain id + description (pack included if present)
    tools/*.json       # one tool per file
    skills/*.json      # optional
    domains/*.json     # optional
    context/*.json     # optional
```

Markdown for humans **and** the assistant lives only under **`doc/`**.  
Assistant-ingested files are named **`doc/ai-*.md`**. There is no `ai/docs/`.

The **module owns** the pack; **ncc-assistant only aggregates** at build time.

## Manifest

```nix
{
  domain = "user";
  description = "User accounts and roles";
}
```

## Tool JSON

| Field | Required | Meaning |
|-------|----------|---------|
| `name` | yes | Prefer `domain.<domain>.<verb>` |
| `description` | yes | Shown to the LLM |
| `inputSchema` | yes | JSON Schema |
| `argv` | yes | Fixed argv; `{{arg}}` substituted; **no shell** |
| `risk` | yes | `read` \| `write` \| `rebuild` |
| `permission` | yes | e.g. `user.create` |
| `confirm` | no | Confirm before write |

## Docs

Short `doc/ai-*.md` files are copied into the assistant knowledge tree (`knowledge/domains/ai-<domain>-<id>.md`).
