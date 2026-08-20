# CLI validation — what is automatic vs manual

## One command (automated)

```bash
bash tests/cli-formatter/validate-cli.sh
```

Legacy alias (docs only): `validate-cli-docs.sh` → calls the same suite.

Also included from repo tests when you build `tests/default.nix`.

### What the automated suite **does** validate

| Check | Means |
|-------|--------|
| Every `commands.nix` has `CLI.md` + status | Docs contract |
| STANDARDS / COPY / api.nix exist | SSOT present |
| No `config.core.management.cli-formatter` in live Nix | Discovery law |
| No private `colors.nix` outside formatter | Palette SSOT |
| No `\033` / `\e[` outside allowlist | No private ANSI |
| Broken `config.${getModuleApi…}` | Catch helper misuse |
| High-traffic scripts import formatter | Update / migrate / packages / … |
| Install-wizard colors wired to formatter | Hub migration |
| `nix-instantiate --parse` on key files | Syntax |
| Smoke build: API shape + colors.sh + postbuild | Builds |
| `test-flake-extras.sh` | Update merge logic unit |
| `test-install-wizard-packaging.sh` | Stale `scripts/checks/` + `{ pkgs }:` leftovers must not break packaging |

### What it **cannot** replace (needs your machine)

| Manual smoke | Why |
|--------------|-----|
| `ncc system update --dry-run --local --source-dir …/nixos` | Needs live `/etc/nixos` flake + real `ncc` on PATH after deploy |
| `ncc system update --dry-run -v …` | Visual / `-v` gating |
| `ncc modules migrate --dry-run` | Live systemConfig layout |
| `ncc install dry-run` | Interactive / host-specific |
| Full `sudo ncc system update` + rebuild | Destructive; only after dry-run looks good |
| GUI wording | Different surface (COPY.md GUI column) |

## Suggested manual pass (after deploy)

```bash
# 1) Automated first
bash tests/cli-formatter/validate-cli.sh

# 2) On the target host (or any NCC machine with /etc/nixos)
ncc system update --dry-run --local --source-dir ~/Documents/Git/NixOSControlCenter/nixos
ncc system update --dry-run -v --local --source-dir ~/Documents/Git/NixOSControlCenter/nixos
ncc modules migrate --dry-run

# 3) Only if dry-run looks right
sudo ncc system update --local --source-dir ~/Documents/Git/NixOSControlCenter/nixos
```

You do **not** need to hand-test every module’s every flag for formatter compliance — the automated suite covers the cross-cutting rules. Hand-test the **update/migrate/install** paths you actually use.
