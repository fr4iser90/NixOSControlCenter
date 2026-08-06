# NCC AI Assistant

Chat with an LLM about your NixOS Control Center config, or expose the same
tools to Cursor / Claude Code via MCP.

## Enable

Minimal config for an OpenAI-compatible gateway (llama.cpp, OpenWebUI, Ollama, …):

```nix
{
  enable = true;
  endpoint = "https://llm.example.com/v1";  # host-only also gets /v1 appended
  allowWrite = true;
  mcpAllowWrite = false;
  allowRebuild = false;
}
```

**Auth:** no `apiKeyFile` needed for normal use. `ncc ai` probes the endpoint; on
401/403 it asks for the key once, auto-detects Bearer vs `X-API-KEY`, and stores
it in `~/.config/ncc-assistant/credentials.json` (0600). Optional
`apiKeyFile` / `apiHeaderName` are only for declarative secrets (sops/agenix)
or MCP without a prior interactive login.

**What you usually leave unset:** `model`, `maxTokens`, `temperature` — the
gateway already knows its model and limits; the client only sends those fields
when you override them.

`api = "openai-compatible"` is the default (Ollama, OpenAI, custom proxies).
Only set `api = "anthropic"` for Anthropic’s native Messages API (then `model`
is required).

Then rebuild so packages and `ncc ai` are installed.

## NCC chat (GUI)

```bash
ncc ai          # graphical window (default)
ncc ai gui
```

On start: pick **New chat** or **Continue** a saved session
(`~/.config/ncc-assistant/sessions/`).

Features:
- Enter send / Shift+Enter newline / **Stop** to cancel
- Streaming replies + markdown bubbles
- Model picker from `GET /v1/models`
- **Img** attach only when the selected model looks vision-capable
- Confirm dialogs for config write / system rebuild tools
- Sessions auto-save; **New** / **Sessions** in the toolbar

Terminal fallback: `ncc ai chat` / `ncc ai cli`.

Keys: env → optional `apiKeyFile` → credentials cache → GUI prompt on 401/403.

## MCP (Cursor / Claude Code)

Start server (stdio):

```bash
ncc ai mcp
# or
ncc-assistant-mcp
```

### Claude Code / Cursor example

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

If the binary is only on the NixOS system profile after enable+rebuild, use the
absolute store path from `which ncc-assistant-mcp` / `readlink -f $(which ncc-assistant-mcp)`.

### Write safety over MCP

`mcpAllowWrite` defaults to **false**. External clients can still
`list_modules`, `read_module_config`, `search_knowledge`, `explain_path`,
`propose_config_patch`, and `validate_config`. Set `mcpAllowWrite = true` only
when you want `apply_module_config` from those clients.

`apply_system` additionally requires `allowRebuild = true` and
`confirm: "CONFIRM"`.

## Tools

| Tool | Purpose |
|------|---------|
| `list_modules` | Registry listing |
| `read_module_config` | Read via config facade |
| `search_knowledge` | Knowledge pack search |
| `explain_path` | Path + registry + current config |
| `propose_config_patch` | Diff only |
| `apply_module_config` | Write via `ncc_write_module_config` |
| `validate_config` | Parse-check Nix fragment |
| `apply_system` | `ncc system build switch` (guarded) |

## Debug

```bash
ncc-assistant tools
ncc-assistant tool list_modules --args '{}'
ncc-assistant tool read_module_config --args '{"module_path":"core/base/packages"}'
```
