# NCC Assistant

AI assistant for NixOS Control Center (`ncc ai` / `ncc-assistant`): chat, agent
tools, MCP, jobs, and related helpers.

## Product surfaces (read this first)

**What is a Workflow vs Skill vs Cron vs Tool vs Plugin?**  
→ **[doc/surfaces.md](./doc/surfaces.md)** (English SSOT)

Short answer: **Workflows** are reusable agent jobs (run once or via Cron).
**Skills** are markdown inside a workflow’s prompt. **Cron** is the timer.
**Tools** / **MCP** are callable capabilities. **Plugins** are desktop host
features (e.g. Doomscroll) — not agent jobs. No Daily board; briefing =
workflow `workspace-brief` + Cron.

## Documentation

- Surfaces (definitions): [doc/surfaces.md](./doc/surfaces.md)
- Usage: [doc/usage.md](./doc/usage.md)
- CLI contract: [doc/cli.md](./doc/cli.md)
- Roadmap: [doc/roadmap.md](./doc/roadmap.md)
