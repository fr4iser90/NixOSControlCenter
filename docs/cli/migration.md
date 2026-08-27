# CLI hierarchy migration (historical)

> **Status: largely complete.** Live contract: [`pattern.md`](./pattern.md).  
> This file is kept as history of the flat → domain CLI move. Do not treat unchecked boxes as current work unless re-verified against `commands.nix`.

---

## Goal (original)

Move from many flat `ncc-*` style commands to:

```
ncc
├── system
├── modules
├── desktop / hardware / network / packages / user / …
├── vm
├── stacks
├── chronicle
├── nixify
└── …
```

No long-lived aliases as the end state — domains own verbs.

## What landed

- **cli-registry** domain registration is the SSOT
- Modules register via `registerCommandsFor` / GUI helpers
- Root `ncc` lists domains; `ncc <domain>` shows actions

## If you still find a flat leftover

1. Move it under the owning module’s `commands.nix`
2. Register through cli-registry
3. Update that module’s `CLI.md`
4. Run `bash tests/run-gates.sh`

## Original plan text

The long phased checklist that used to live here targeted an older “6 domains only” snapshot. The product now has **many** domains (see [`domains.md`](../domains.md)). Prefer domains.md + cli/pattern.md over re-implementing that checklist blindly.
