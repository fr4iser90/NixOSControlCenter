# CLI — install-wizard

> SSOT: [STANDARDS](../cli-formatter/doc/standards.md) · [COPY](../cli-formatter/doc/copy.md)

**Status:** `compliant`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc install …` | Guided install | yes (`--dry-run` / `ncc-install-dry`) | varies |

## Self-audit

- [x] `colors.sh` generated from `getModuleApi "cli-formatter"`
- [x] `logging.sh` bridges formatter palette + badge tags; honors `NCC_CLI_NESTED=1`
- [x] Dry-run banner: `Preview only — nothing will be written under /etc/nixos`
- [x] Main `init` flow: header → dry banner → work → result → `Next:`
- [x] README links here

## Notes

Script tree packaging passes `getModuleApi` into all script nix files.
Nested callers set `NCC_CLI_NESTED=1` so children skip header / dry banner / Next.

**Step copy still evolving** — intermediate wizard prompts/sections use the logging bridge but have not had a full copy.md wording pass. Skeleton for the main install command is met.
