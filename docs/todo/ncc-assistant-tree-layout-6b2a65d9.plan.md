---
name: ncc-assistant tree layout
overview: "Kein python-/assistant-/ncc_assistant-Sammelordner: Surfaces und Shared-Code als Top-Level-Pakete neben data/doc/ai/ui — ein Ordner = ein Zweck. Packaging bleibt appRoot-Staging; Reload-Kopplung in gui-engine und die JSON-Loader sind Teil der Arbeit, nicht Folgekosten."
todos:
  - id: move-catalogs
    content: "Phase 1: Catalogs nach data/{agents,mcp,playbooks,skills,eval}; prompts/ → data/prompts; Loader + Env-Umhängung"
    status: pending
  - id: phase1-gate
    content: "Phase 1 abschließen: Gate grün mit NCC_GUI_PYTHON (Qt-Tests laufen nachweislich mit)"
    status: pending
  - id: hoist-packages
    content: "Phase 2: python/ncc_assistant zerlegen → Top-Level companion/ harness/ plugins/ core/ cli/"
    status: pending
  - id: decouple-reload
    content: "gui-engine reload.py: Paketnamen-Tupel (\"ncc_gui\",\"ncc_assistant\") auflösen — sonst stale GUI"
    status: pending
  - id: rewrite-imports
    content: "Relative Imports → core./companion./harness./plugins.*; 5 Entrypoints `python -m ncc_assistant` umbiegen"
    status: pending
  - id: test-bootstrap
    content: "sys.path in tests/ncc-assistant/conftest.py zentralisieren statt 39 Dateien einzeln"
    status: pending
  - id: wire-package-nix
    content: "package.nix: appRoot-Staging auf die Top-Level-Pakete; PYTHONPATH nur auf Site-Root (nicht Modulroot); NCC_DATA_ROOT"
    status: pending
  - id: collision-gate
    content: "Kollisions-Gate: Site-Root == Soll-Menge, kein Name existiert bereits in pythonEnv/ncc_gui"
    status: pending
  - id: layout-gate
    content: "Layout-Gate auf ncc-assistant gescoped in bestehende gates/ erweitern (kein neues Gate, kein Repo-weites python/-Verbot)"
    status: completed
  - id: path-rot
    content: "Pfad-Rot: schedules.nix-Kommentare, doc/plans/*.md, README, knowledge/README.md, data/templates/"
    status: pending
  - id: ssot-doc
    content: "doc/layout.md: Top-Level-Mappe + Regel ui/ (Shell-Seite) vs companion/ (eigene Surface)"
    status: pending
  - id: gates-green
    content: tests/run-gates.sh exit 0
    status: pending
isProject: false
---

# ncc-assistant Tree — Surfaces oben, kein Sammel-Package

## Kritik am letzten Plan

Ein Ordner `assistant/` (oder `ncc_assistant/` / `python/`) ist wieder nur ein Mülleimer. Du willst **Companion, Harness, Plugins, Data usw. direkt unter dem Modul** — nicht nochmal eingepackt.

Der Ist-Zustand gibt das her: `python/ncc_assistant/` liegt **69 `.py` auf einer Ebene** — `companion.py` (126 KB), `gui_pages.py` (98 KB), `gui.py` (91 KB), `cli.py` (75 KB) direkt neben `paths.py`, `llm.py`, `session.py`. Oberflächen und Kern sind nicht trennbar, weil sie im selben Ordner wohnen.

Messbarer erster Schnitt: von den **69** `.py` auf Paketebene importieren **9 PySide6**, 60 sind Qt-frei (plus 2 Qt-Dateien in `plugins/doomscroll/` → 11 im ganzen Paket).

**Korrektur an dieser Stelle.** Die erste Fassung behauptete, die Surfaces seien Blätter mit „0 eingehenden Imports". Das war ein kaputtes grep-Muster (`grep -rl "import .*\b$f\b"` — lieferte außerdem `grep: --include=*.nix: No such file or directory`). Gemessen mit `grep -rnE "from \.$f import|import \.$f"`:

| Qt-Datei | KB | IN (eingehende Rel.-Imports) | OUT | wird importiert von |
|---|---|---|---|---|
| `companion` | 123 | 2 | 28 | `cli.py:1901`, `tray` |
| `gui_pages` | 96 | **7** | 30 | `gui`, `companion`, `templates_ui` |
| `gui` | 89 | **5** | 14 | `cli.py:1957`, `tray`, `companion` |
| `templates_ui` | 41 | **4** | 9 | `gui`, `companion`, `gui_pages` |
| `provider_ui` | 9 | 3 | 3 | `gui`, `gui_pages` |
| `focus_actions` | 9 | 3 | 2 | `focus`, `companion` |
| `companion_themes` | 6 | 3 | 0 | `companion`, `gui` |
| `tray` | 4 | 1 | 7 | `cli.py:652` |
| `morning_brief_settings` | 6 | 0 | 4 | nur Plugins/Tests |

Wahr ist die *schwächere* Aussage: die Surfaces werden **lazy** betreten (aus `cli.py` und Tests). Blätter sind davon nur `companion`, `tray`, `morning_brief_settings`. `gui_pages`, `templates_ui`, `provider_ui`, `companion_themes` sind **gemeinsame Qt-Bausteine von `gui` und `companion`** — ein naives „Qt-Datei → `companion/`" erzeugt eine Kante `gui → companion`. Die Qt-Schicht muss deshalb **gespalten** werden (Surface vs. gemeinsame Widgets), nicht verschoben. Das ist der Grund, warum dieser Plan eine Zuordnungstabelle braucht und keinen Sortier-Befehl.

## Nix statt Python? — Nein (Non-Goal)

Alles nach Nix „portieren" wäre **schlechter**, nicht besser:

| Schicht | Richtig in |
|---------|------------|
| Options, schedules, packaging, discovery, system-update | **Nix** (`*.nix`, `lib/`, `package.nix`) |
| Catalogs (agents/mcp/playbooks/skills) | **Daten** (`data/*.json|md`) |
| Companion (Qt), LLM, MCP client, harness adapters, CLI verbs | **Python** (Top-Level-Packages) |

Nix evaluiert Config und baut Store-Pfade — es ist keine Runtime für Chat-Streams, PySide6-Fenster oder Agent-Tool-Loops. Ein Port wäre ein Rewrite in einer anderen Sprache (Go/Rust/…) plus trotzdem Packaging in Nix — kein Gewinn für den Tree.

**Besser:** Tree wie unten trennen; Nix bleibt dünn (wire + package), Python nur in klaren Surface-/Core-Ordnern, Daten nur in `data/`.

## Zielbaum

```
ncc-assistant/                    # Nix-Modul (discovery)
  default.nix  options.nix  commands.nix  package.nix  …
  lib/                            # Nix helpers (discover-domain-ai, discover-modules-index)
  doc/                            # Docs (usage.md, cli.md, layout.md)
  ai/                             # Domain-AI-Pack (Gate-Pflicht: ai/manifest.nix)
  ui/gui/page.py                  # Control-Center page — NCC-Shell
  data/                           # ONLY Daten, kein Code
    agents/*.json                 # war python/ncc_assistant/templates/agents (29)
    mcp/*.json                    # war python/ncc_assistant/templates/mcp (4)
    playbooks/*.json              # war python/ncc_assistant/playbooks (4)
    eval/cases.json               # war python/ncc_assistant/eval/cases.json
    prompts/system.md             # war prompts/system.md
    prompts/skills/*.md           # war prompts/skills (11)
    knowledge/README.md           # erklärt $out/knowledge (built, nicht source)

  companion/                      # Surface: Avatar-Overlay (war companion.py + themes/store/skins)
  window/                         # Surface: Multi-Tab-Fenster (war gui.py, startet `ncc ai gui`)
  tray/                           # Surface: Tray-Daemon (war tray.py)
  widgets/                        # GEMEINSAME Qt-Bausteine (gui_pages, templates_ui, provider_ui)
  harness/                        # coding harness adapters (bleibt, ist schon sauber)
  plugins/                        # feature plugins: doomscroll (+ focus*), morning_brief
  core/                           # shared runtime, Qt-frei — in Gruppen, nicht flach (siehe Zuordnung)
    runtime/  policy/  store/  scheduling/  catalogs/  workflows/  render/
  cli/                            # Entrypoint: __main__.py + argparse/verbs
```

Vier Surfaces, nicht eine: `companion` (Overlay), `window` (Hauptfenster), `tray`, `widgets` (geteilt). Die Aufteilung ist **gemessen erzwungen**, nicht Stil — `gui_pages`/`templates_ui`/`provider_ui` hängen gleichzeitig an `gui` und `companion`; `widgets/` ist der einzige Ort, der keine Kante `gui → companion` erzeugt.

Kein `python/`. Kein `ncc_assistant/`. Kein `assistant/`.

| Top-Level | Zweck |
|-----------|--------|
| `companion/` | Desktop-Fenster / Avatar-UI (Qt, eigene Surface) |
| `harness/` | Qwen/DSH/native adapters |
| `plugins/` | Feature plugins |
| `core/` | Gemeinsame Logik (nicht surface-spezifisch) |
| `cli/` | CLI-Entrypoint |
| `data/` | JSON/MD catalogs only |
| `ai/` / `ui/` / `doc/` / `lib/` | NCC-Modul-Konvention |

```mermaid
flowchart TB
  mod[ncc-assistant]
  mod --> companion
  mod --> harness
  mod --> plugins
  mod --> core
  mod --> cli
  mod --> data
  mod --> ai
  mod --> ui
  mod --> doc
  cli --> core
  companion --> core
  harness --> core
  plugins --> core
  core -->|NCC_DATA_ROOT| data
```

Konventions-Präzedenz ist da: `validate-module-shape.sh` verlangt pro Modul `template-config.nix`, `ai/manifest.nix`, `doc/usage.md` (das `ai/`/`doc/` also Pflicht, kein Wunsch). Flache Oberflächen-Ordner existieren bereits: `chronicle/` (`plugins/ analysis/ handlers/ …`), `ai-workspace/` (`llm/ services/ schemas/`), `nixify/` (`data/`).

## Korrekturen gegen den gemessenen Ist-Zustand

Die erste Fassung des Plans ging von drei Dingen aus, die nicht stimmen. Messwerte (2026-10-23, Working Tree):

| Annahme im alten Plan | Gemessen | Folge |
|---|---|---|
| `PYTHONPATH=Modulroot` | `package.nix:23-37` baut `appRoot = pkgs.runCommand "ncc-assistant-src"`, kopiert `python/ncc_assistant` → `$out/ncc_assistant` (`:24`), `prompts` (`:25`), `knowledge` (discoveriert), `AI_KNOWLEDGE.md`, `ncc_gui` (von gui-engine). `PYTHONPATH="${appRoot}"` (`:252`). Die Modulquelle war **nie** auf dem Pfad. | Modulroot auf PYTHONPATH würde `ai/ doc/ lib/ ui/` zu importierbaren Namespace-Ordnern machen — `lib/` enthält ausschließlich `.nix`. Staging-Root bleibt, Inhalt ändert sich. |
| Catalogs liegen schon in `data/` | `data/` enthält **nur leere Ordner** (`data/playbooks`, `data/templates/mcp`) und ist **nicht in git**: `git ls-files …/data` → leer. Ein Klon hat kein `data/`. | `data/` entsteht erst durch den Umzug; Gate auf „Pflicht-Ordner" zieht vorher nicht. |
| `prompts/` ist ein Stub, „weg" damit | `prompts/` ist der **lebende** Prompt-Katalog: `package.nix:25` (`cp -r ${./prompts} $out/prompts`), `package.nix:171` (`NCC_PROMPTS_ROOT`), `config.py:196-200` (Default `root/prompts`), `agent_templates.py:278` (liest die Skill-MDs). | Ohne Env-Umhängung verliert das gepackte Assistant **still** seine Skills. Umbenennen ja — aber als Daten-Umzug mit Env-Contract, nicht als Löschen. |

## Blast-Radius außerhalb des Moduls (der teure Teil)

Der Rename ist **nicht** auf `ncc-assistant` begrenzt. 58 Dateien außerhalb des Pakets referenzieren `ncc_assistant` (`.py|.sh|.nix|.md`, ohne `docs/todo`). Tragend:

**1. `nixos/core/management/gui-engine/python/ncc_gui/reload.py`** hartcodiert das Tupel `("ncc_gui", "ncc_assistant")` an 6 Code-Stellen — `:195`, `:201`, `:252`, `:269`, `:284` (+ Docstring `:8`, `:265`) — für Modul-Cache-Purge und Store-Pfad-Erkennung des Hot-Reloads. Nach `core/ companion/ cli/` purgiert der Reload **nichts mehr**: die GUI läuft mit veralteten Modulen weiter, ohne dass irgendetwas rot wird.

Der einzige Wächter ist `tests/gui/test_reload_generation.py`, und der läuft **nur, wenn PySide6 verfügbar ist** (`tests/gui/validate-gui-python.sh:88`, sonst `SKIP` auf `:90`). Ein grüner `run-gates.sh` ohne `NCC_GUI_PYTHON` beweist hier also **nichts**. Dieselbe Datei hartcodiert die Wrapper-Form (`test_reload_generation.py:58`: `…/bin/python -m ncc_assistant "$@"`) und muss mitziehen.

Außerdem 6 weitere `tests/gui/*.py` mit `ncc_assistant`-Referenz: `test_template_language_param.py`, `desktop_quiet_runner.py`, `test_ask_card_smoke.py`, `test_companion_window_smoke.py`, `test_companion_feed_smoke.py`, `test_domain_pages_smoke.py`.

**2. `python -m ncc_assistant` ist der Entrypoint von 5 Wrappern** in `package.nix`: `:288` (`exec … "$@"`), `:295`, `:315` (mcp), `:321` (tray), `:327` (companion). Alle fünf müssen auf denselben neuen Namen; einer vergessen = ein Surface, das erst beim Aufruf stirbt.

**3. Generische Top-Level-Namen auf geteiltem Interpreter.** `core` `cli` `data` `plugins` `harness` landen auf dem `sys.path` des `python3.withPackages`-Sets, in dem auch `ncc_gui` liegt. `python -m cli` ist der generischste denkbare Entrypoint. Das ist kein Stil-, sondern ein Kollisionsrisiko → eigenes Gate (unten), nicht Konvention.

**Kollisionsfläche richtig gemessen.** Die erste Fassung hielt `ncc_gui/widgets.py` für einen harten Konflikt gegen das geplante `widgets/`. Ist es nicht: gemessen liegt in `${appRoot}` genau **zwei** importierbare Top-Level-Namen (`ncc_assistant`, `ncc_gui`); `widgets` innerhalb von `ncc_gui` ist ein **Submodul** (`ncc_gui.widgets`) und für `import widgets` nicht sichtbar. Zusätzlich nutzt `ncc_gui` durchgängig paketqualifizierte Selbst-Imports (`from ncc_gui…`, 20+ Dateien, **0** bare-absolute) — ein hoistendes `widgets/` bricht also auch die GUI nicht. Die echte Fläche ist damit:

| Kandidat | Grund | Prüfbar ohne Build? |
|---|---|---|
| pythonEnv site-packages (`mcp httpx pyside6` + Transitiv) | dieselbe Interpreter-Wurzel | **nein** — braucht den Build oder eine ausgehandelte Liste |
| alles Weitere, das nach `${appRoot}` gestaged wird | `runCommand` kann ungeplant名前 liefern | ja — Soll-Menge der `appRoot`-Einträge |
| Python-Stdlib | `import core` verdeckt nichts, `import types` schon | ja — `sys.stdlib_module_names` |
| `ncc_gui` Top-Level | nur `ncc_gui` selbst | ja — aus `package.nix`-Staging |

Daraus folgt die Gate-Formulierung unten: **Soll-Menge der Site-Root-Einträge + Stdlib-Freiheit**, nicht „kein Name existiert schon in `ncc_gui`". Der site-packages-Anteil bleibt als Restrisiko dokumentiert und ist nur per Build schließbar.

## Loader, die `data/` erst kennen müssen

Ein Umzug der JSON aus dem Paket raus ist **kein reiner `git mv`** — vier Stellen leiten die Pfade aus der Paketstruktur ab:

| Stelle | Heute | Braucht |
|---|---|---|
| `playbooks.py:58` | `resources.files("ncc_assistant") / "playbooks"` | `NCC_DATA_ROOT` + Pfadauflösung; `importlib.resources` funktioniert nur für Dateien **in einem importierbaren Package** |
| `eval_harness.py:123` | `resources.files("ncc_assistant") / "eval"` | dito |
| `agent_templates.py:216` (+ Fallback `:220/221`) | `Path(__file__).parent / "templates" / "agents"`, Fallback über `Path(root)/"ncc_assistant"/"templates"/"agents"` | Ein Pfad über `NCC_DATA_ROOT`; die Fallback-Kette ist wörtlich an den Paketnamen `ncc_assistant` gekettet |
| `marketplace.py:90` (+ Fallback `:95/96`) | `Path(__file__).parent / "templates" / "mcp"` | dito |

Dazu die Prompt-Seite: `config.py:196-200` (`NCC_KNOWLEDGE_ROOT`, `NCC_PROMPTS_ROOT` mit Default `root/…`) und `agent_templates.py:278`. `NCC_DATA_ROOT` allein wirkt nicht, solange diese Defaults auf `root/prompts` stehen bleiben.

## Packaging (korrigiert)

[`package.nix`](nixos/modules/specialized/ncc-assistant/package.nix) — appRoot-Staging bleibt die Architektur, es wird nur um die neuen Pakete und einen sauberen Site-Root erweitert:

```nix
appRoot = pkgs.runCommand "ncc-assistant-src" { } ''
  # Site-Root: ausschließlich importierbare Pakete — kein doc/, kein lib/, keine .nix
  mkdir -p $out/lib/ncc-assistant
  cp -r ${./companion} ${./harness} ${./plugins} ${./core} ${./cli} $out/lib/ncc-assistant/
  cp -r ${./data} $out/data
  …                                  # knowledge (discoveriert), AI_KNOWLEDGE.md, ncc_gui wie bisher
  export … NCC_DATA_ROOT=$out/data   # NCC_PROMPTS_ROOT zeigt auf $out/data/prompts
'';
```

- `PYTHONPATH = $out/lib/ncc-assistant` — **nicht** die Modulroot. Damit bleibt der Zielbaum oben flach (dein Ziel) und trotzdem kein `.nix`/`doc/` auf dem Importpfad.
- Entrypoint: ein `cli/__main__.py`, die 5 Wrapper rufen alle `-m cli`. Empfehlung: `cli` intern als `run(argv)`-Funktion, damit `-m cli` nur ein Dünnschicht-Aufruf ist.
- `NCC_PROMPTS_ROOT` bleibt als Contract erhalten (zeigt jetzt nach `data/prompts`) — die Konsumenten in `config.py`/`agent_templates.py` müssen explizit umgehängt werden, sonst frisst der Default `root/prompts` die Änderung auf.

Imports (Richtung): `from core.paths import …`, `from companion import run_companion`, `from harness.resolve import …`. Heute ist fast alles **relativ** importiert (`.paths` 31×, `.config` 16×, `.preferences` 10×, `.runtime`/`.permissions` je 9× …) — Oberflächen-übergreifende relative Imports (`from .x` aus `harness/`, `plugins/`) müssen zu absoluten werden. Das ist die eigentliche Rewrite-Arbeit, nicht das `git mv`.

GUI Control-Center-Seite bleibt `ui/gui/page.py` (NCC-Shell; `validate-module-surfaces.sh` Regel 3/4 prüft genau das). Companion ist absichtlich **nicht** unter `ui/` — die Regel („`ui/` = NCC-Shell-Seite, `companion/` = eigene Surface") gehört in `doc/layout.md`, sonst wächst der Ordner beim nächsten Feature wieder zu.

## Zuordnung (die 69 Dateien)

Das ist das Artefakt, das der Plan vorher nicht hatte — ohne es rät jeder, der das ausführt, bei 60 Dateien neu. Grundlage: Docstring-Rolle + gemessene Qt-Farbe + Fan-in. **Kein Zyklus in der Qt-Schicht** (gemessen), deshalb ist die Trennung überhaupt möglich.

**Surfaces (Qt, 9 Top-Level-Dateien)**

| Heute | Ziel | Warum genau dort |
|---|---|---|
| `companion.py` (123 KB) | `companion/window.py` | IN nur aus `cli.py:1901` + `tray` |
| `companion_store.py` | `companion/store.py` | IN 1: nur `companion` |
| `avatar_skins.py` | `companion/skins.py` | IN 1: nur `companion` |
| `gui.py` (89 KB) | `window/app.py` | Surface `ncc ai gui`; IN aus `cli.py:1957` + `tray` + `companion` |
| `tray.py` | `tray/daemon.py` | IN 1: `cli.py:652` |
| `gui_pages.py` (96 KB) | `widgets/pages.py` | **IN 7** aus `gui`, `companion`, `templates_ui` — kein Surface-Blatt |
| `templates_ui.py` (41 KB) | `widgets/templates.py` | IN 4 aus `gui`, `companion`, `gui_pages`, `morning_brief_settings` |
| `provider_ui.py` | `widgets/providers.py` | IN 3 aus `gui`, `gui_pages` |
| `companion_themes.py` | `widgets/themes.py` | Name lügt: IN aus `companion` **und** `gui` |

**Plugins**

| Heute | Ziel | Warum |
|---|---|---|
| `focus.py` (28 KB) | `plugins/doomscroll/watchdog.py` | Doomscroll ist schon als `FeaturePlugin` gebaut (`plugins/doomscroll/__init__.py`) |
| `focus_actions.py` (Qt) | `plugins/doomscroll/actions.py` | **Pflicht mitzunehmen**: `focus.py:727,746` importiert es lazy, `focus_actions` importiert zurück → Zyklus. Getrennte Pakete wären zirkulär. |
| `focus_netblock.py` | `plugins/doomscroll/netblock.py` | IN 1: nur `focus` |
| `plugins/doomscroll/{privilege_ui,settings_ui}.py` | bleiben | sind schon richtig |
| `morning_brief.py` | `plugins/morning_brief/logic.py` | IN 1: nur `morning_brief_settings` |
| `morning_brief_settings.py` (Qt) | `plugins/morning_brief/settings_ui.py` | ersetzt den existierenden Shim |

**Totcode, vorher entscheiden (nicht mitumbauen):** `plugins/morning_brief/{logic,settings_ui}.py` nennen sich selbst „Compat shim"/„Shim — use `ncc_assistant.morning_brief`"; `plugins/__init__.py::list_plugins()` liefert **nur** `DoomscrollPlugin()`; 0 Code-Referenzen auf `plugins.morning_brief` im ganzen Repo. Einziger Beleg ist `tests/ncc-assistant/test_morning_brief_plugin.py`, und der beweist das Gegenteil (brief ist **kein** Plugin). → Beim Umzug löschen statt verschieben, Test bleibt als Regel-Wächter.

**`core/` — 50 Dateien, in Gruppen. Flach wäre der alte Mülleimer mit neuem Namen.**

| Gruppe | Dateien |
|---|---|
| `runtime/` | `runtime` (IN13) · `registry` (IN21) · `llm` · `session` · `agent` · `context` · `capacity` · `mcp_client` · `mcp_server` · `argv_template` · `history` · `memory` |
| `store/` | `preferences` (**IN57**) · `paths` (IN37) · `config` (IN30) · `workspaces` (IN27) · `presence` (IN18) · `providers` · `jobs` · `secrets` · `host_profiles` · `shortcuts` |
| `policy/` | `permissions` (49 KB, IN18) · `auth` (IN17) · `audit` (IN12) · `budgets` · `profiles` · `red_team` · `notifications` |
| `scheduling/` | `idle` (IN14) · `schedule_templates` (IN15) · `schedule_freq` · `watchdogs` · `probes` · `poll_guard` · `chain_guard` |
| `catalogs/` | `agent_templates` (IN16) · `marketplace` (IN10) · `playbooks` (IN11) · `eval_harness` · `health` · `maintenance` · `diff_review` |
| `workflows/` | `workflows` (IN14) · `workflow_execute` (42 KB) · `workspace_workflow` · `workspace_lifecycle` |
| `render/` | `transcript` · `export_transcript` · `trace_format` |

**`cli/`** `cli.py` (74 KB, OUT 38, IN 1) · `__main__.py` · `chat.py` (Terminal-REPL-Fallback) · `cli_print.py` · `__init__.py` (die Public-API-Re-Exports wandern nach `core/__init__.py`, sonst brechen 22 Tests, die `from ncc_assistant import …` schreiben)

**Entschieden (2026-02, vom Owner):** (1) `window/` — nicht `gui/`, um die Verwechslung mit `ui/gui/page.py` (Shell-Seite) zu vermeiden; (2) eigenes `widgets/` für die geteilten Qt-Bausteine — alles Qt nach `companion/` zu kippen erzeugt die Kante `window → companion`; (3) `chat.py` → `cli/` (IN nur aus `cli`). Damit ist die Zuordnung vollständig, der Ausführer hat keine Namensentscheidung mehr.

## Tests

- **41** Dateien in `tests/ncc-assistant/`, **39** referenzieren `ncc_assistant`, und fast jede hartcodiert denselben Bootstrap: `ROOT = REPO / "nixos/modules/specialized/ncc-assistant/python"` + `sys.path.insert(0, str(ROOT))` (z. B. `test_doomscroll_focus_v1.py:16-17`). **33 Dateien** containen das wörtliche Pfadliteral `ncc-assistant/python`.
  → `sys.path` **einmal** in `tests/ncc-assistant/conftest.py` (der macht bisher nur XDG-/Desktop-Isolation), 39 Dateien verlieren ihre zwei Zeilen. Sonst ist jeder künftige Ordner-Rename wieder eine 39-Dateien-Aktion.
- Das Assistant-Python-Gate läuft über ein **Verzeichnis** (`tests/gates/validate-ncc-assistant-python.sh` → `pytest "${ROOT}/tests/ncc-assistant" -q`), nicht über eine Dateiliste — keine stillen Auslassungen. `tests/gui/validate-gui-python.sh` dagegen listet **hart einzeln** (`:72-97`); `test_reload_generation.py` ist dort PySide6-conditioned (`:88`).
- Für Phase 1 **und** Phase 2 gilt: Gate-Lauf mit `NCC_GUI_PYTHON=<nix-env>/bin/python bash tests/run-gates.sh` und im Log per `grep "test_reload_generation" <log>` nachweisen, dass die Qt-Tests wirklich liefen (`Ran N tests` / `OK`). Ohne den Nachweis ist „Gate grün" für die Reload-Kopplung wertlos.

## Gate (scoped + capability-entziehend)

Bestehende Gates erweitern statt neue erfinden — `validate-module-shape.sh` (Pflicht-Skeleton), `validate-module-surfaces.sh` (CLI/GUI/docs), `validate-nix-import-paths.sh` sind die Andockstellen.

1. **Scope: nur `ncc-assistant`.** Ein repo-weites `python/`-Verbot wäre sofort rot — `nixos/core/management/gui-engine` hat legitimerweise ein eigenes `python/` (das ist `ncc_gui` selbst).
2. **Verboten** unter `nixos/modules/specialized/ncc-assistant/`: `python/`, `ncc_assistant/`, `assistant/`.
3. **Pflicht**: `companion/ core/ cli/ harness/ plugins/` und `data/{agents,mcp,playbooks,eval,prompts}`.
4. **Kein Code in `data/`**, keine `*.json`-Catalogs unter `core/ companion/ harness/ plugins/ cli/`.
5. **Kollisions-Check (hart, Build-/Gate-Zeit):** der Site-Root enthält exakt die Soll-Menge Pakete, und keiner der Namen existiert bereits in `pythonEnv` oder im aus gui-engine kopierten `ncc_gui`. Nicht „bitte generische Namen vermeiden", sondern: der Check schlägt fehl, wenn `import core` zwei Kandidaten hätte.
6. **Entrypoint-Check:** die 5 Wrapper zeigen alle auf denselben Modulnamen; `python -m <name>` ist im gebauten Paket löschbar (Smoke).

Punkt 5 und 6 sind die einzigen, die den Fehler *unmöglich* machen statt ihn nur zu melden — 1-4 sind Fänger.

## Schritt 0 — gelandet (2026-10-23)

Gate **vor** dem Umbau, sonst kann es den Umbau nicht prüfen. Ist als heute-grüner Ratchet gebaut, weil
`pre-commit` das ganze Netz fährt: eine heute rote Prüfung würde jeden Commit bis Phase 2 blockieren.

`tests/gates/validate-assistant-layout.sh` (in `validate-ncc-nix.sh` als 19/19 eingehängt — kein zweites Netz):

| Check | Entfernte Fähigkeit |
|-------|---------------------|
| `appRoot`-Soll-Menge `{AI_KNOWLEDGE.md, knowledge, ncc_assistant, ncc_gui, prompts}` | Kein ungeplanter Top-Level-Name landet auf `PYTHONPATH` |
| Stdlib-Freiheit des importierbaren Top-Levels + `sys.path`-Bann | Ein Hoist darf kein stdlib-Modul verdecken; kein Pfropf macht Submodul-Namen importierbar |
| `data/` frei von Code | Katalog-Wurzel kann nicht zum Paket werden |
| Loader-Zeugen `playbooks` + `eval_harness` | Die stille `return []`-Degradation ist rot, nicht „klar, läuft" |
| Provenanz auf Wegwerf-Kopie | Loader dürfen nicht aus einem installierten/stalen `ncc_assistant` lesen |
| Ein Entrypoint + `--help`-Smoke über 4 Verbs | Ein Wrapper darf nicht auf einem eigenen Modul landen und nicht schweigend sterben |
| Ratchet: 69 flache Module | Neuer Code darf nicht in den flachen Haufen |

Bite bewiesen in `tests/ncc-assistant/test_layout_gate_v1.py` (11 Tests: 10 Angriffe + Kontrolle),
Daten-Contract zusätzlich fixiert in `tests/ncc-assistant/test_catalog_loaders_v1.py` (15). Gemessen:
`run-gates.sh` exit 0, Assistant-Suite 636 passed, Gate läuft ohne Profilzugriff (`XDG_CONFIG_HOME`
isoliert, `HOME` real — sonst fehlt httpx aus dem user site-packages).

**Restrisiko, das erst Phase 2 schließt:** Kein Gate baut `package.nix`, also bleibt die Kollision im
`pythonEnv`-site-packages Anteil (Punkt 5 oben) messbar nur per Build. Das absolute Verbot von
`python/ncc_assistant/` und die Pflicht-Soll-Menge `companion/ core/ cli/ harness/ plugins/` kommen mit
Phase 2 in dasselbe Gate — `EXPECTED_STAGED` und `FLAT_CEILING` werden dann **gesenkt**, nicht erhöht.
Ein beim Gate-Entwurf gefundenes Loch (Wrapper auf `-m ncc_mcp` blieb grün, weil der grep den Namen
nicht traf) ist geschlossen: verglichen wird jetzt die Menge **aller** `python -m <mod>`-Ziele.

## Reihenfolge: zwei lieferbare Schritte

Ein Schwung aus Daten-Umzug **und** Python-Aufteilung hat einen beweisbar kaputten Zwischenstand (`importlib.resources` bricht, `appRoot` kopiert den falschen Ordner, Reload purgiert nichts). Deshalb:

**Phase 1 — Daten (klein, unabhängig grün):**
1. `python/ncc_assistant/{templates/agents,templates/mcp,playbooks,eval}` → `data/{agents,mcp,playbooks,eval}`; `prompts/` → `data/prompts/`.
2. Die 4 Loader + `config.py`-Defaults auf `NCC_DATA_ROOT`/`NCC_PROMPTS_ROOT` umstellen; `package.nix` kopiert `data/`.
3. Gate grün (mit `NCC_GUI_PYTHON`) → **Commit**. Paketname bleibt `ncc_assistant`, Reload ist unberührt, nichts am Importbaum.

**Phase 2 — Surfaces (der große mechanische Teil):**
4. `python/ncc_assistant/` aufteilen → `companion/ harness/ plugins/ core/ cli/`; `python/` löschen.
5. Relative → absolute Imports; 5 Entrypoints; `test_reload_generation.py:58`.
6. `reload.py` Paketnamen-Tupel auflösen (konfigurierbare Liste statt Literal) — zusammen mit `tests/gui/test_reload_generation.py`.
7. `conftest.py`-Bootstrap; 39 Test-Dateien bereinigen.
8. Gates (Layout + Kollision + Entrypoint), Pfad-Rot nachziehen, `doc/layout.md`.
9. `bash tests/run-gates.sh` exit 0, Qt-Log-Nachweis → **Commit**.

Größerer mechanischer Rename als nur Ordner-hoisten — bewusst, damit der Tree der mentalen Modell-Trennung entspricht. Die zwei Commits sind es auch, damit zwischen den Phasen jeweils ein grüner Gate mit gelaufenen Qt-Tests steht.

## Ausführung: Branch, Agent, und was die Gates eben *nicht* fangen

**Branch: ja — und zwar ein `git worktree`, nicht nur ein Branch.** Zwei gemessene Gründe:

1. `.githooks/pre-commit` ist `exec bash "$ROOT/tests/run-gates.sh"` — die **volle** Kette bei *jedem* Commit. Phase 2 hat einen beweisbar kaputten Zwischenstand, also ist „häppchenweise committen" nicht möglich: der erste Commit nach Beginn von Phase 2 ist schon der komplette. Ein Branch, in dem trotzdem gestückelt wird, ist eine Illusion.
2. `main` ist der Auslieferungsstand (`ncc system-update --local …/nixos` zeigt auf diesen Checkout). Wer im Haupt-Checkout refactored, deployed zwischenzeitlich den halbfertigen Baum. Ein Worktree hält `main` deploybar, während Phase 2 läuft:
   ```bash
   git worktree add ../ncc-tree -b refactor/ncc-assistant-tree
   ```

**Die Gates validieren dieses Refactor nicht — sie sehen die riskanteste Zone nicht.** Messprotokoll unten; die drei Löcher:

| Lücke | Messwert | Folge |
|---|---|---|
| **Kein Gate baut `package.nix`.** | In `tests/gates/*.sh` kommt kein `nix build` vor; `nix eval`/`nix-instantiate --eval` laufen nur auf `#nixosModules`, `#lib` und Modul-Eval. `package.nix` wird in Tests nur als **Text** gelesen (`test_run_length_budgets.py:106,122`). Es gibt **kein Paket-Flake-Output**: `nixos/flake.nix` exportiert nur `nixosModules` + `lib`, `package.nix` wird intern von `schedules.nix:10`, `commands.nix:21`, `api.nix:6`, `focus-block.nix:16` importiert. | Genau das ist die Zone, in der dieser Umbau stirbt: `appRoot`-Staging, `PYTHONPATH`, 5 Entrypoints, Namens-Kollision. Alles grün, `ncc ai` tot. |
| **Zwei der vier Loader haben 0 Tests.** | `grep -rl playbooks tests/ncc-assistant --include='*.py'` → **0**; `eval_harness` → **0**. (`marketplace` 3, `agent_templates` 8.) | Phase 1 ist an `playbooks.py:58` und `eval_harness.py:123` unbewacht — und das sind die beiden `importlib.resources`-Stellen, die beim Umzug *garantiert* ihre Datei verlieren. |
| **Der Reload-Wächter ist optional.** | `tests/gui/validate-gui-python.sh:88` (PySide6), sonst `SKIP` auf `:90`. | `reload.py` purgiert nach dem Rename nichts mehr — die GUI läuft still mit stale Modulen. |

**Deshalb die Reihenfolge, nicht die andere:**

1. **Gate zuerst, Umbau danach.** Layout- + Kollisions- + Entrypoint-Check *gegen den Ist-Baum* schreiben: sie sind heute grün (der Ist-Baum erfüllt sie, sobald `data/` gefüllt ist) und werden rot, sobald der Umbau etwas vergisst. Ein Gate, das nach dem Umbau entsteht, kann den Umbau nicht prüfen.
2. **Die zwei fehlenden Loader-Tests vor Phase 1** (`playbooks`, `eval_harness`) — sonst ist Phase 1 der eine Schritt, den das Repo nicht sieht.
3. **Erst dann ein Agent.** Delegierbar ist der mechanical Teil: `git mv`, die 4 Loader, `conftest.py`-Bootstrap, die 39 Test-Bootschriften, `schedules.nix`-Kommentare. **Nicht** delegierbar: die Zuordnung oben (60 Entscheidungen, begründet, sie ist die Arbeit — nicht das `mv`), `package.nix`, und `reload.py` in einem *fremden* Modul.
4. **Retry-Schleife ist nicht kostenlos.** Jeder Agent-Durchlauf ist ein voller `run-gates.sh` auf diesem Host, mit Session-Bus und Wayland — kein CI-Container. Ein Agent, der „solange probiert bis grün" macht, probiert das auf dem Desktop.

## Pfad-Rot (mitmähen, sonst Lüge im Repo)

- `schedules.nix:53` (`python/ncc_assistant/permissions.py`), `:241` (`poll_guard.py`), `:268` (`chain_guard.py`) — Kommentare, die Invarianten an Dateipfade binden.
- `doc/plans/*.md` (u. a. `38-repo-account-fact-store.md`, `39-permission-ladder-and-schedule-grants.md`), `README.md`, `doc/surfaces.md`.
- `knowledge/README.md` → Ziel benennen (`data/knowledge/README.md`), weil `$out/knowledge` **gebaut** wird (discoverte `ai/`-Packs) und nicht mit Quellcode verwechselt werden darf.
- `data/templates/mcp` (leer) existiert nur auf der Platte, nicht in git — beim Umzug auflösen, nicht „mitnehmen".

## Messprotokoll (2026-10-23, dieses Repo)

```bash
git ls-files nixos/modules/specialized/ncc-assistant/data        # → leer (data/ ist nicht in git)
ls nixos/modules/specialized/ncc-assistant/python/ncc_assistant/*.py | wc -l   # 69
ls tests/ncc-assistant/test_*.py | wc -l                          # 41
grep -rl ncc_assistant tests/ncc-assistant --include='*.py' | wc -l   # 39
grep -rl "from ncc_assistant import" tests/ncc-assistant/*.py | wc -l # 22  (Public-API-Importe, keine Submodule)
grep -rl "ncc-assistant/python" . --include='*.py' --include='*.sh' --include='*.nix' --include='*.md' \
  | grep -v docs/todo | wc -l                                     # 33
grep -rl ncc_assistant . --include='*.py' --include='*.sh' --include='*.nix' --include='*.md' \
  | grep -v "ncc-assistant/python/" | grep -v docs/todo | wc -l    # 58
grep -n "ncc_assistant" nixos/core/management/gui-engine/python/ncc_gui/reload.py  # :8 :195 :201 :252 :265 :269 :284
grep -rn -- "-m ncc_assistant" --include='*.nix' --include='*.py' . | grep -v docs/todo   # package.nix :288 :295 :315 :321 :327 + test_reload_generation.py:58
grep -n 'resources\.files' nixos/modules/specialized/ncc-assistant/python/ncc_assistant/{playbooks,eval_harness}.py

# Qt-Schicht (9 von 69 Top-Level, dazu 2 in plugins/doomscroll) — IN/OUT pro Datei, kein Zyklus:
python3 - <<'PY'   # läuft in python/ncc_assistant/
import re, pathlib
d = pathlib.Path("."); qt = {f.stem for f in d.glob("*.py") if "PySide6" in f.read_text(errors="replace")}
for f in sorted(d.glob("*.py")):
    src = f.read_text(errors="replace")
    inn = sum(len(re.findall(rf"from \.{f.stem} import|import \.{f.stem}\b", g.read_text(errors="replace")))
              for g in d.glob("*.py") if g != f)
    print(f.stem, "Qt" if f.stem in qt else "-", inn, len(set(re.findall(r"from \.([a-z_0-9]+) import", src))))
PY

# Gates sehen Packaging nie:
grep -rn "nix build\|nix-instantiate" tests/gates/*.sh        # nur --parse / --eval, nie ein Build von package.nix
grep -n "packages" nixos/flake.nix                            # kein Paket-Output — nur nixosModules + lib
grep -rn "import ./package.nix" nixos/modules/specialized/ncc-assistant/*.nix   # :10 :21 :6 :16 (intern)
# Loader ohne Test:
for m in playbooks eval_harness marketplace agent_templates; do echo -n "$m "; grep -rl "$m" tests/ncc-assistant --include='*.py' | wc -l; done   # 0 / 0 / 3 / 8
```
