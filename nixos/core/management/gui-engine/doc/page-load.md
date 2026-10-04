# Domain page load + loading states (SSOT)

**Binding** with [performance.md](./performance.md) and [gui-design.md](./gui-design.md).
Kit API: `DomainPage` in `python/ncc_gui/scaffold.py`.

## Goal

Sidebar nav must paint the new page **immediately** (skeleton + Loading).
Heavy work (`ncc … status`, FS probes, catalog fill) runs **after** first paint,
with a visible loading state. Never block the UI thread on construct with sync `ncc`.

## Lifecycle

```text
Nav click
  → shell mounts DomainPage (widgets only)
  → schedule_load(reload)   # QTimer 0 — after paint
  → begin_load("Loading…")  # banner + content muted
  → async ncc status / short work
  → fill widgets
  → end_load()
```

| Phase | UI |
|-------|-----|
| Mount | Title, empty/default widgets, footer actions |
| Loading | Banner under scope: “Loading …” · content slightly muted · actions disabled |
| Ready | Banner hidden · widgets filled · actions enabled |
| Error | `end_load()` + Activity / dialog as today (banner off) |

## Kit API

| Method | Role |
|--------|------|
| `schedule_load(fn)` | Run `fn` on next event-loop tick (first paint first). Cancels prior scheduled load on same page. |
| `begin_load(message=…)` / `end_load()` | Refcounted loading UI (nested safe). |
| `is_loading` | True while count &gt; 0. |
| `load_ncc_status(*args, on_result=, label=)` | `begin_load` + async `ncc` (no Activity spam) + `on_result(code, stdout)` + `end_load`. |

`on_done` for `run_ncc_async` / `run_ncc_root` may be `fn(code)` or `fn(code, output)`.

## Rules for `ui/gui/page.py`

1. **Construct:** build widgets only. Prefer `self.schedule_load(self.reload)` over `self.reload()`.
2. **`reload`:** call `begin_load` / `end_load` (or use `load_ncc_status`).
3. **Status / list:** prefer `load_ncc_status` or `run_ncc_async` — not sync `run_ncc` / `remote.run_ncc` on the hot path.
4. **Sync fallbacks** (read systemConfig files): OK inside `begin_load` after paint; keep them short.
5. **Do not** show modal errors for “still loading”; use the banner.

## Metrics (dev)

```bash
NCC_GUI_LOAD_DEBUG=1 ncc
```

Logs to stderr:

- `schedule gen=N` — load scheduled after mount
- `ready in Xms` — wall time from outermost `begin_load` → matching `end_load` (data ready, **not** first paint)

### Budgets (what “good” means)

| Metric | Target | Notes |
|--------|--------|--------|
| First paint after nav | **≤ 16–50 ms** | One event-loop tick; widgets only. `schedule_load` exists for this. **Not** printed by debug. |
| `ready in` (local FS / baked JSON) | **≤ ~100 ms** | Ideal for status from files / env catalogs. |
| `ready in` (`ncc … --json`) | **100–500 ms typical** | CLI start + work. Must stay **async** so UI does not freeze. |
| `ready in` (heavy list, e.g. modules) | **often ~0.5–1.5 s** | OK **if async + banner** (UI stays responsive). Not a 50 ms goal until cached/baked. |

**Do not** aim for `ready in ≤ 50 ms` for every page while it shells out to `ncc`. Aim for **instant paint + banner**, then fill when data arrives.

The contract gate **passes** while sync-reload debt remains on an allowlist — a green gate is not “all pages ≤ 50 ms”. Long `ready in` with a banner is expected; a **frozen** UI means sync `run_ncc` on the UI thread (forbidden for new pages).

Nav rebuilds the document; in-flight `QProcess` must be killed via `abort_background_work` (otherwise Qt warns `Destroyed while process is still running`).

## Gate (contract + UI-thread ms budget)

`tests/gui/test_page_load_states.py` (via `validate-gui-python.sh` / `run-gates.sh`)
enforces two layers:

### 1) Contract (AST)

| Check | Fail when |
|-------|-----------|
| Kit API | Missing `schedule_load` / `begin_load` / `load_ncc_status` / `abort_background_work` |
| Shell unmount | `_destroy_page` does not abort in-flight `ncc` |
| Mount | `__init__` calls `self.reload()` sync (must `schedule_load` or `QTimer.singleShot(0,…)`) |
| Loading UI | `reload` / `_initial_load` without `begin_load` / `load_ncc_status` (except tiny legacy allowlist) |
| Sync CLI debt | New sync `run_ncc` inside load methods (must use async, or temporary allowlist) |

### 2) UI-thread budget (**ms**, stubbed `ncc`)

Hard fail if `reload()` / `load_ncc_status(…)` **blocks the UI thread** longer than
**50 ms** while `ncc` is stubbed to be slow (200 ms+). That is the gate for
“accidental sync load / freeze”.

| Metric | In CI? | Meaning |
|--------|--------|---------|
| Time until `reload()` returns | **Yes** ≤ 50 ms | UI stayed responsive; async started |
| Live `ready in` (`NCC_GUI_LOAD_DEBUG`) | **No** | Real CLI wall time; host-dependent |

CI does **not** fail on live `modules ready in 1100ms` — that is CLI work. It
**does** fail if that 1100 ms runs on the UI thread (sync `run_ncc`).

**Product rule:** paint → banner → fill → ready. First-paint / UI-return ≤ 50 ms
is gated; data-ready time is measured manually with `NCC_GUI_LOAD_DEBUG`.

## Tests

| Concern | Where |
|---------|--------|
| Page-load contract (AST + kit runtime) | `tests/gui/test_page_load_states.py` |
| Hot-path AST (no probe on soft) | `tests/gui/test_hot_path_perf.py` |
