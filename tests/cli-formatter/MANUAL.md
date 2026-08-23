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
| No `\033` / `\e[` outside allowlist (`.nix` + `.sh`) | No private ANSI |
| No `echo -e` private colors in `*.sh` outside allowlist | No private shell palettes |
| Broken `config.${getModuleApi…}` | Catch helper misuse |
| High-traffic scripts import formatter | Update / migrate / packages / … |
| Install-wizard colors wired to formatter | Hub migration |
| `nix-instantiate --parse` on key modules | Syntax |
| Smoke build: API shape + colors.sh + postbuild | Builds |
| `test-flake-extras.sh` | Generic host extras (aliases + fake `acme-hw`) |
| `tests/hardware/jetson/test-flake-extras-jetson.sh` | Jetson `jetpack` kept as real extra |
| `test-install-wizard-packaging.sh` | Stale `scripts/checks/` + `{ pkgs }:` leftovers |
| No `ui.messages` splice in one-line braces | Bash `; }` bug |

### UX skeleton (must match STANDARDS §3)

Parent command owns: **header → dry banner → … → result → Next:**  
Nested (`NCC_CLI_NESTED=1`): work + result lines only.

### What it **cannot** replace (needs your machine)

| Manual smoke | Why |
|--------------|-----|
| `ncc system update --dry-run --local --source-dir ~/…/nixos` | Needs readable `/etc/nixos` + real `ncc` after deploy |
| `ncc system update --dry-run -v --local --source-dir ~/…/nixos` | Visual / `-v` gating |
| `ncc modules migrate --dry-run` | Live systemConfig layout |
| `ncc install dry-run` | Interactive / host-specific |
| Full `sudo ncc system update` + rebuild | Destructive; only after dry-run looks good |
| GUI wording | Different surface (COPY.md GUI column) |

## Suggested manual pass (after deploy)

```bash
# 1) Automated first
bash tests/cli-formatter/validate-cli.sh

# 2) On the target host (readable /etc/nixos)
ncc system update --dry-run --local --source-dir /path/to/nixos
ncc system update --dry-run -v --local --source-dir /path/to/nixos
ncc modules migrate --dry-run

# 3) Only if dry-run looks right
sudo ncc system update --local --source-dir /path/to/nixos
```

Expect one header, one dry-run banner, one **Next:** line — not nested duplicate headers.

You do **not** need to hand-test every module flag for formatter compliance — the automated suite covers cross-cutting rules. Hand-test the **update/migrate/install** paths you use.
