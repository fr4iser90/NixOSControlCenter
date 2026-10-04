# AGENTS — NixOS Control Center (NCC)

**Tool-agnostic entry** for any coding agent (Cursor, Claude Code, Codex, Aider, CI bots, …).  
Humans: start at [README.md](README.md).

## What this repo is

Declarative NixOS control plane: install wizard, `ncc` CLI/TUI/GUI, modules under `nixos/`.  
Hosts deploy the **`nixos/`** tree via `ncc system-update` (not the whole git root).

## Hard laws (always — this file is SSOT)

1. Module identity / config **only** via discovery + `getModuleConfig` / `getModuleApi` — never hardcode `config.core.…` or invent helpers like `getModuleNixConfig`.
2. **Never** read `cfg = systemConfig.${dottedPath};` (dotted string ≠ nested path).
3. Docs live in `<module>/doc/` only — no `ai/docs/`, no root `cli.md`.
4. **Never** read/write live `/etc/nixos`, `/run/current-system`, or host profiles unless the user pastes that path/output.
5. Before claiming `nixos/` works or telling the user to `ncc system-update`:  
   `bash tests/run-gates.sh` → **exit 0 in this turn**.
6. Bash in Nix `''` strings: shell vars as `''${VAR}`; Nix as `${pkgs…}`.
7. Version bump + `<module>/migrations/` only when hosts need cleanup — not for docs/additive defaults.
8. Tests only under repo-root `tests/` — never `nixos/**/test_*.py` (would deploy).

## Layout

```
AGENTS.md                        # ← you are here (all agents)
.agents/skills/*/SKILL.md        # portable workflow skills
.githooks/pre-commit             # real Git hooks
scripts/install-git-hooks.sh     # wires core.hooksPath → .githooks
nixos/…
tests/
docs/
```

No `.cursor/` tree — laws and skills are portable above.  
Wire Git gates (any clone):

```bash
bash scripts/install-git-hooks.sh
# also self-heals when you run: bash tests/run-gates.sh
```

Sibling (optional): `../NCC-Hyperland-Collection` — applyable Hyprland rices.

## Before you finish a `nixos/` change

```bash
bash tests/run-gates.sh
```

Must exit **0**. Do **not** tell the user to `ncc system-update` otherwise.  
Details: [tests/TESTING.md](tests/TESTING.md).

## Workflow skills

| Task | Skill |
|------|--------|
| Gates / validate / pre-update | [.agents/skills/ncc-hard-gates/SKILL.md](.agents/skills/ncc-hard-gates/SKILL.md) |
| Edit/add modules, migrations | [.agents/skills/ncc-module-work/SKILL.md](.agents/skills/ncc-module-work/SKILL.md) |
| Hyprland rice / collection | [.agents/skills/ncc-hyprland-rices/SKILL.md](.agents/skills/ncc-hyprland-rices/SKILL.md) |
| GUI Python / catalog | [.agents/skills/ncc-gui-python/SKILL.md](.agents/skills/ncc-gui-python/SKILL.md) |

## Human docs next

| Doc | Use when |
|-----|----------|
| [docs/developing/new-module.md](docs/developing/new-module.md) | Adding a module |
| [docs/developing/docs-conventions.md](docs/developing/docs-conventions.md) | Docs layout |
| [nixos/core/management/cli-formatter/doc/standards.md](nixos/core/management/cli-formatter/doc/standards.md) | `ncc` quiet checklist UX |
| [nixos/core/base/hyprland/doc/usage.md](nixos/core/base/hyprland/doc/usage.md) | Rice install / apply |

## Deploy note

User runs: `ncc system-update --local …/nixos`.  
Agents edit **this git repo only**.
