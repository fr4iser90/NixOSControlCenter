# CLI / GUI copy rules (NCC)

**Full standards (API inventory, update UX, audit):** [STANDARDS.md](./STANDARDS.md)

## Default tone

| Surface | Tone |
|---------|------|
| **GUI** | Plain language. No store paths, no raw exceptions. Optional “Details”. |
| **CLI (normal)** | Clear + short. One path is OK (e.g. backup done). No stack traces. |
| **CLI `--verbose` / `-v`** | Full technical detail: diffs, rc codes, long paths, JSON. |

## Always use `cli-formatter`

```nix
ui = getModuleApi "cli-formatter";
# ${ui.messages.info "…"} ${ui.messages.success "…"} ${ui.messages.error "…"}
```

Do not invent per-script color/`echo` styles.

## Never splice `ui.messages.*` inside one-line `{ …; }` / `fn() { …; }`

`ui.messages.*` ends with a newline. This breaks Bash:

```bash
# BAD → expands to:  log() { printf …\n; }
log() { ${ui.messages.success "$*"}; }
[[ -f "$f" ]] || { ${ui.messages.error "missing"}; exit 1; }
```

```bash
# GOOD — full statements, or single-line printf via ui.colors
${ui.messages.error "missing"}
exit 1

# or
c = ui.colors;
# …
[[ -f "$f" ]] || { printf '%b\n' "${c.red}missing${c.reset}" >&2; exit 1; }
```

## Verbose pattern in shell

```bash
${ui.messages.success "Backup created"}
if [ "$VERBOSE" = "true" ]; then
  ${ui.messages.info "Backup path: $BACKUP_DIR"}
fi
```

## Validate updates without writing

```bash
# Full update preview (config + module migrations + flake extras merge)
ncc system update --dry-run --local --source-dir /path/to/NixOSControlCenter/nixos
# optional: -v for layout, JSON previews, diff hints

# Module migrations only
ncc modules migrate --dry-run
```

Dry-run must not touch `/etc/nixos`. The `ncc` wrapper skips `sudo` when `--dry-run` is present (and `-d` for `system update`). Real update keeps host flake extras by default.
