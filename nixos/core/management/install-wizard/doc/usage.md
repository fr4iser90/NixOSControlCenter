# Install Wizard — Usage

Guided NixOS Control Center install (`ncc install …`), including dry-run preview that does not write under `/etc/nixos`.

## Entry

```bash
ncc install --help
```

Typical flow: pick host profile → stage `systemConfig` → review → apply (or dry-run).

## Docs

| Doc | Topic |
|-----|--------|
| [cli.md](./cli.md) | CLI contract + Status |
| [../scripts/README.md](../scripts/README.md) | Scripts overview |
| [../README.md](../README.md) | Module stub |

Repo install overview: [docs/install.md](../../../../../docs/install.md).
