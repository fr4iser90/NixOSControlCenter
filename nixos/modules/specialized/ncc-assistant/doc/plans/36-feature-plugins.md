# Phase 36 — Feature plugins (not MCP / templates / watchdogs)

**Status:** Phase A done (seam + Plugins tab + doomscroll extracted)  
**Depends on:** doomscroll (35), companion (29–33), Settings UX

## Problem

Doomscroll lived under **Settings 4f** — hardwired. More desktop features would
bloat Settings and confuse:

| Surface | Owns |
|---------|------|
| **Plugins** (this phase) | Enableable desktop features (doomscroll, …) |
| **Tools → MCP marketplace** | External MCP servers |
| **Templates** | Agent goal templates |
| **Schedules → Watchdogs** | Event → agent job |
| **Settings** | Core: LLM, secrets, presence, capacity, host |

## Architecture

```text
plugins/
  __init__.py          FeaturePlugin protocol, list_plugins, tick_all
  doomscroll/
    __init__.py        DoomscrollPlugin
    settings_ui.py     Configure UI (moved from Settings 4f)

GUI: Plugins tab → list + enable + configure panel
Companion/tray: tick_all(host=…) instead of importing focus directly
```

## Phase A (done)

- [x] Plugin protocol + registry
- [x] Doomscroll as first builtin plugin
- [x] Settings 4f removed → pointer to Plugins
- [x] Companion/tray use `tick_all`
- [x] Morning Brief as second builtin plugin (digest schedule/sources)
- [x] Companion Plugins panel (list / toggle / configure)
- [x] Doomscroll net-block privilege grant at enable (`auth-check`)
- [x] Polkit YES rule for `org.nixos.ncc.focus-netblock` (no mid-scroll password)
- [x] Docs + tests

## Later

- Catalog/marketplace JSON (install = enable; still no untrusted download)
- Deep Work / Break Coach plugins
- Generic interrupt presenter (drop doomscroll-named companion helpers)
