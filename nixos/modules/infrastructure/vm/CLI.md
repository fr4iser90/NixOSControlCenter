# CLI — vm

> SSOT: [STANDARDS](../../../core/management/cli-formatter/doc/STANDARDS.md) · [COPY](../../../core/management/cli-formatter/doc/COPY.md)

**Status:** `partial`

## Commands

| Command | Purpose | Dry-run | Needs root |
|---------|---------|---------|------------|
| `ncc vm …` | Test VMs / ISO / ports | N/A | group kvm/libvirtd |

## Self-audit

- [x] `ui = getModuleApi "cli-formatter"` threaded through `lib/{vm,iso-manager,port-manager}.nix`
- [x] ❌/⚠️ status echoes → `ui.messages` (port / ISO path stdout stays raw)
- [ ] Remaining informational emoji in `vm.nix` (🚀/💡/etc.) not yet migrated
- [ ] Verbose detail gated with `-v`
- [ ] `longHelp` matches COPY tone
- [ ] README links here

## Notes

Machine output (`echo -n "$VM_PORT"`, `printf '%s' iso_path`) intentionally raw.
