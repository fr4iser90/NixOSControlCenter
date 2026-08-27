# NCC GUI Performance (SSOT)

**Binding** for Qt pages, shell, Target session, and embedded apps (e.g. AI chat).
Layout/UX remain in [GUI-DESIGN.md](./GUI-DESIGN.md); this doc covers **what may block the UI** and **what may be cached**.

## 1. UI thread rules

1. **No network on the UI thread** — HTTP (`httpx`, GitHub, `/models`, …) must be async, deferred, or served from a warm in-memory catalog.
2. **No long sync `subprocess` / `ncc` on the UI thread** — prefer `run_ncc_async` / `QProcess`. Sync `run_ncc` only for short, user-initiated actions where blocking is expected (and timeouts stay modest).
3. **Soft generation (multi-domain shell)** — refresh **catalog/chrome**, then **recreate the current document** (`NccShell`). Do not keep a stack of stale domain pages. Standalone domain windows may `reload()` if visible. Sticky `ai`/`ssh` are parked on navigate but cleared/recreated on soft when relevant.
4. **Target probe** — only on **Connect** (or explicit Refresh while remote). Never on every nav switch or idle timer.
5. **Activity restore** — loading `~/.cache/ncc/gui-activity/` on page construct is OK (capped). Do **not** dump live `ncc … status` into Activity on load ([GUI-DESIGN §](./GUI-DESIGN.md)).

### Chrome + Document

| Piece | Role |
|-------|------|
| Chrome | Shell sidebar, Target bar, gate banner — projects `ShellChromeState` + target session |
| Document | Exactly one mounted domain page (plus optional parked sticky `ai`/`ssh`) |
| Soft | Catalog reload + nav rebuild + **force remount** current domain |
| Hard | Process `exec` when kit/code digest changes |

Hot paths that must stay cheap: **chat/session switch**, **sidebar nav** (dispose/mount, no probe), **soft generation** (no SSH), **Target candidate change** (selection ≠ Connect).

## 2. Cache policy

### Cache (read-mostly catalogs)

| Data | Where / how | Invalidate when |
|------|-------------|-----------------|
| API credentials | `ncc_assistant` disk cache (`~/.config/ncc-assistant`) | Logout / re-auth / endpoint change |
| `ncc user whoami` | `@lru_cache` in assistant permissions | User/role change; `clear_whoami_cache()` |
| LLM model list | In-memory on `ChatSession`; reuse on chat switch (`refresh_models=False`) | Provider/endpoint change, explicit Refresh |
| Domain catalog | Loaded at shell start / soft generation | Soft/hard generation |
| Host list (`~/.creds`) | Target bar / SSH client page | User refresh / ssh client edit |
| Target probe result | `TargetSession` until Disconnect / re-probe | Disconnect, Connect, explicit Refresh |

Optional TTL (5–15 min) is fine for model lists if a manual Refresh exists.

### Do **not** cache (or only with hard invalidation)

- Live system status (release, generation, module on/off)
- Auth probe after 401 / failed key
- Agent/tool step results
- “SSH still up” — re-check on Connect / user Refresh

Stale live state after rebuild is worse than a short async refresh.

### Activity disk persist

`save_activity` / `load_activity` are **session continuity**, not a performance cache.

- Cap: `ACTIVITY_MAX_CHARS` (see `ncc_gui.reload`)
- Prefer debouncing writes if logging becomes hot
- Truncate on save/load; never grow unbounded

## 3. What to prefer in page code

| Do | Don’t |
|----|--------|
| `run_ncc_async` / `QProcess` for status + long CLI | Sync `run_ncc` inside `reload()` / constructors |
| Reuse catalogs on switch (`available_models=…`) | `list_models` / GET `/models` on every chat switch |
| Soft-reload / soft recreate **current document** only | Soft-reload every stacked page |
| Connect → probe once | Probe on every Target combo change |
| Explicit Refresh for live fields | Background polling without need |
| Dispose domain page on navigate (Activity on disk) | Keep 15 live pages as a status cache |

## 4. Regression tests

Prove hot paths with unit/AST tests (no live rebuild / no real HTTP):

| Concern | Test location |
|---------|----------------|
| Chat switch must not call `list_models` | `ncc-assistant/.../tests/test_chat_switch_blocks_on_list_models.py` |
| Soft reload visibility / chrome-document + activity cap | `tests/gui/test_hot_path_perf.py` |
| Generation soft vs hard | `tests/gui/test_reload_generation.py` |

When adding a new sync network or CLI call on a switch/nav/construct path, add a test that **fails if that call runs**.

## 5. Checklist (PR / page review)

- [ ] No HTTP or long `subprocess` on construct / nav / chat switch / soft generation (hidden pages)
- [ ] Catalogs reused or fetched async; live status only async or on Refresh
- [ ] Target probe only on Connect (or explicit remote Refresh)
- [ ] Activity empty until an action; disk persist capped
- [ ] New hot-path guard covered by a unit/AST test when non-obvious
