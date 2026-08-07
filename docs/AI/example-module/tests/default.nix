# Example module tests

Real validation (not stubs):

```bash
# From repo root — must pass for all modules, including this template's patterns
bash shell/scripts/checks/modules/validate-no-hardcoded-paths.sh
```

When adding a module from this template, ensure:

1. `moduleName = baseNameOf ./.` (no string literal name in wiring)
2. `cfg = getModuleConfig moduleName`
3. Options under `options.${(getCurrentModuleMetadata ./.).configPath}`
4. No `config.core.…` / relative imports of other modules
