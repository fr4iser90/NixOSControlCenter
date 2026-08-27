# Documentation placement & naming

## Law

**One docs home per module: `doc/`.**  
Filenames: **kebab-case**. Root may only have `README.md` / `CHANGELOG.md`.

Gate: `tests/validate-docs-layout.sh`. Rule: `.cursor/rules/ncc-docs-layout.mdc`.

---

## Where

| Content | Location |
|---------|----------|
| Project-wide (install, features, domains, …) | repo **`docs/`** |
| **All** module prose (usage, architecture, cli, AI blurbs, roadmap, …) | **`nixos/<module>/doc/`** |
| AI tool JSON + manifest | **`<module>/ai/`** (not markdown) |
| Runtime prompts | **`<module>/prompts/`** |

Assistant-ingested blurbs: **`doc/ai-*.md`** (e.g. `doc/ai-overview.md`).

---

## Module template

```
<module>/
  README.md              # short stub → links into doc/
  doc/
    usage.md
    cli.md
    architecture.md      # if needed
    ai-overview.md       # if AI pack (optional)
    …
  ai/
    manifest.nix
    tools/*.json
```

No `ai/docs/`. No root `cli.md`.
