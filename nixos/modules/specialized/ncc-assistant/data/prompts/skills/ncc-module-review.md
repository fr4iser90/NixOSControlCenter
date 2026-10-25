# NCC Module Review

Review module changes against NixOS Control Center laws.

## Checklist

1. Identity via `baseNameOf` / discovery; config via `getModuleConfig` / `getModuleApi` only.
2. No `systemConfig.${dottedPath}` reads; no hardcoded `config.core.*`.
3. Docs only under `<module>/doc/`.
4. Migrations only when hosts need cleanup.
5. Suggest `bash tests/run-gates.sh` before deploy claims.

Stop early on out-of-scope refactors. Prefer findings + suggested patches over rewriting whole modules.
