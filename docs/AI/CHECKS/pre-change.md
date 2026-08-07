# Pre-change checks

Before large module work:

1. Read `docs/AI/RULES.md` and `.cursor/rules/ncc-module-discovery.mdc`
2. Skim `docs/AI/example-module/MODULE_TEMPLATE.md` (Forbidden section at top)
3. Prefer `getModuleConfig` / `getModuleApi` / `baseNameOf ./.` — never literal `core.management.*` paths. Peer NixOS attrs: `(getModuleApi "…").fromConfig config`
