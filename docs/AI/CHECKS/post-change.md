# Post-change checks (required)

Run after any edit under `nixos/core` or `nixos/modules`:

```bash
bash shell/scripts/checks/modules/run-all.sh
```

Covers hardcoded paths **and** `(import ./commands.nix {…})` / missing helper args.
