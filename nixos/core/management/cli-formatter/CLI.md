# CLI — cli-formatter

> SSOT: [STANDARDS](./doc/STANDARDS.md) · [COPY](./doc/COPY.md) · [API](./doc/API.md)

**Status:** `compliant` (this module *is* the formatter)

## Role

Core always-on module. Other modules must use:

```nix
ui = getModuleApi "cli-formatter";
```

## Offers

See [STANDARDS §2](./doc/STANDARDS.md) — messages, badges, text, tables, lists, boxes, progress, prompts, spinners, fzf, menus, tui, colors.

## Planned helpers

`ui.flow.{dryRunBanner,step,confirmYesNo,verboseGate,copyableError,nextHint}` — listed in STANDARDS §2 gaps.

## Self-audit

- [x] Single palette in `colors.nix`
- [x] API exported via `api.nix` / `getModuleApi`
- [x] Docs (`API.md` / `ARCHITECTURE.md` / `USAGE.md`) use `getModuleApi "cli-formatter"` only
- [x] COPY + STANDARDS for other modules
