# CLI — stack-manager

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc stacks status` | Docker / Swarm / config facts | N/A (`--json`) | no |
| `ncc stacks fetch` | Clone/update catalog into virt home | no (N/A) | virt/admin user |
| `ncc stacks list-profiles` | Profiles for this host (arch filter) | N/A | no |
| `ncc stacks list-catalog` | Individual `group/service` entries | N/A | no |
| `ncc stacks install` | `--profile` bundle **or** single `group/service` | no | virt/admin |
| `ncc stacks init` | Catalog installer (profiles) | no (N/A) | virt user |
| `ncc stacks ops\|swarm\|list-*` | Day-2 / running Docker inventory | no | varies |
| `ncc stacks manager` | TUI | N/A | no |

## Catalog browse (no permanent fetch)

```bash
# Ephemeral clone — does not write virt home
ncc stacks list-profiles --remote
ncc stacks list-profiles --remote --plain   # name|family|arch|ok
ncc stacks list-catalog --remote
ncc stacks list-catalog --remote --plain    # group/service|variants
ncc stacks list-catalog --remote --family compute -v

# Or point at a checkout
NCC_STACKS_ROOT=~/Documents/Git/NCC-Stacks ncc stacks list-profiles
```

After `fetch`, lists use `/home/<virt|admin>/…` automatically.

## Install

```bash
sudo -u <virt> ncc stacks install --profile homelab-core
sudo -u <virt> ncc stacks install media/jellyfin
```

**Profile** = bundle. **group/service** = single catalog stack (`stacks.sh start`).

## Output contract

- status / fetch / init / list-profiles / list-catalog / install: header → loading → facts/badges → success → one `Next:`
- Honors `NCC_CLI_NESTED=1`
- Machine helpers (`list-containers` / ports / domains): pipe-delimited raw (intentional)
- Catalog scripts under `$HOME/…/docker-scripts` own chrome when delegated (`ops`)

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` in commands + handlers
- [x] Skeleton + `NCC_CLI_NESTED` on new catalog list/install
- [x] `--remote` browse without fetch into virt home
- [x] Arch filter on `list-profiles` (default); `--all` / `-v` for mismatches
- [ ] TUI / GUI catalog picker — list CLI first; GUI still shows **running** Docker
- [x] README links here

## Notes

Alias: `ncc homelab` → `ncc stacks`.

Default catalog: `https://github.com/fr4iser90/NCC-Stacks.git`.

**Arch:** profile `arch:` field; refuse on install via catalog `load_profiles` (`NCC_FORCE_PROFILE=1` override).

**GPU:** compose variants (`arm/`/`cpu/`/`rocm/`), not a separate list filter yet.
