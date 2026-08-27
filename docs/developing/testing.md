# Testing (developers)

SSOT: [`tests/TESTING.md`](../../tests/TESTING.md).

```bash
bash tests/run-gates.sh          # hard gate before commit / system-update
bash tests/validate-ncc-nix.sh   # Nix + catalog subset
bash tests/gui/validate-gui-python.sh
```

Git pre-commit is wired **automatically** (`scripts/install-git-hooks.sh` via Cursor `sessionStart` and the first `run-gates.sh`). Manual fallback: `bash scripts/install-git-hooks.sh`.

- Suites live only under **`tests/`** — never under `nixos/` (would deploy).
- Hosts run **preflight / migrations** as product code; they do **not** run this suite.
