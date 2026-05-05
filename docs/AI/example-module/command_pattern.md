Alles klar! Ich sehe, dass du das `ncc`-CLI-Pattern vereinheitlichen willst und interne Hilfsbefehle (z. B. für Discovery, Automatisierung etc.) mit einer `--internal`-Flag versehen willst, damit sie nicht in der normalen Benutzerliste auftauchen, aber dennoch ausführbar sind. Ich passe dein bestehendes Command-Layout komplett an das neue Pattern an.

Hier ist die überarbeitete Version:

---

## NCC CLI – Struktur (Ziel-Architektur)

```text
ncc [global-flags] [module] [submodule] [command] [target/options] [flags]
```

* **Ziel:** Hierarchische Commands wie `ncc module-manager get-module-data`
* **Aktuell:** Top-level Commands wie `ncc module-manager` (CLI Registry muss erweitert werden)
* **Commands via Registry:** Alle Commands werden über `cliRegistry.registerCommandsFor` registriert
* **Interne Commands:** `internal = true;` markieren (nicht in öffentlicher Hilfe)
* **Module als Plugins:** Einheitlich aktiviert/deaktiviert über `module enable/disable`
* **Registry-Parameter:** `permission`, `dangerous`, `requiresSudo`, `internal`, etc.

---

## Registry Command Parameter (Ziel-Spezifikation)

Für die hierarchische CLI-Architektur sollen diese Parameter verfügbar sein (CLI Registry muss erweitert werden):

```nix
(cliRegistry.registerCommandsFor "namespace" [
  {
    name = "command-name";           # Command-Name (erforderlich)
    description = "Beschreibung";    # Kurze Beschreibung (erforderlich)
    script = "${script}/bin/script"; # Ausführbares Script (erforderlich)
    category = "kategorie";          # Gruppierung in Hilfe
    type = "command";                # "command" oder "manager"

    # Permissions & Security
    permission = "system.manage";    # Erforderliche Berechtigung
    requiresSudo = true;             # Benötigt sudo
    dangerous = true;                # Zeigt Gefahren-Warnung
    internal = true;                 # Versteckt in öffentlicher Hilfe

    # Argumente & Hilfe
    arguments = ["arg1", "arg2"];    # Erlaubte Argumente
    shortHelp = "cmd - kurz";        # Einzeiler-Hilfe
    longHelp = "Detaillierte Hilfe"; # Lange Hilfe-Text

    # Zusätzlich
    dependencies = ["nix", "git"];   # Erforderliche Pakete
    interactive = false;             # Benötigt Benutzer-Interaktion
    priority = 100;                  # Sortierung (niedriger = wichtiger)
  }
])
```

---

### Module Management (Plugins)

```bash
# Infrastructure-Module
ncc module enable homelab-manager
ncc module disable homelab-manager

ncc module enable ssh-server-manager
ncc module disable ssh-server-manager

# Security-Module
ncc module enable ssh-client-manager
ncc module disable ssh-client-manager

# Specialized-Module
ncc module enable ai-workspace
ncc module disable ai-workspace

ncc module enable hackathon
ncc module disable hackathon
```

---

### Testing & Validation

```bash
# Dry-Run Mode (Simulation)
ncc --dry-run module enable homelab
ncc --dry-run system update

# Validation
ncc validate config
ncc validate system

# Vollständige Testsuite
ncc test all
```

---

### Deployment & Updates

```bash
# NCC selbst
ncc self update
ncc self check
ncc self backup

# Multi-Environment Management
ncc env list
ncc env switch production
```

---

### Monitoring & Health-Checks

```bash
# System Monitoring
ncc monitor start
ncc monitor status
ncc monitor alerts

# Health-Checks
ncc health system
ncc health modules
ncc health full
```

---

### Internationalisierung & Themes

```bash
# Sprache & Theme
ncc config language de
ncc config theme dark
ncc config theme minimal

# Lokalisierung
ncc locale set de_DE
ncc locale list
```

---

### Backup & Recovery

```bash
# Backup-Strategien
ncc backup create full
ncc backup create config
ncc backup create selective

ncc backup list
ncc backup restore <id>
ncc backup verify <id>
```

---

### Integration & APIs

```bash
# JSON APIs
ncc api modules
ncc api system

# Web-Interface
ncc web start
ncc web status
```

---

### Advanced Features

```bash
# Batch Operations
ncc batch run script.ncc
ncc batch create

# Remote Management
ncc remote connect server
ncc remote execute "module enable homelab"

# Scheduling
ncc schedule add "daily" "system update"
ncc schedule list
ncc schedule remove <id>
```

---

### Interne / Hilfs-Commands

> Diese werden mit `internal = true;` markiert und erscheinen nicht in der normalen Hilfe.

**Registry-Beispiel:**
```nix
(cliRegistry.registerCommandsFor "module-manager" [
  {
    name = "module-manager";
    description = "Interactive module management TUI";
    script = "${bubbleTeaTui}/bin/ncc-module-manager";
    category = "system";
    permission = "system.manage";
    requiresSudo = true;
    dangerous = false;
  }
  {
    name = "get-module-data";
    description = "Internal: Get module discovery data";
    script = "${moduleDiscoveryScript}/bin/get-module-data";
    category = "system";
    internal = true;  # Versteckt in öffentlicher Hilfe!
    permission = "system.manage";
  }
])
```

**Verwendung:**
```bash
# Öffentlich sichtbar
ncc module-manager  # TUI starten

# Intern (nicht in Hilfe gelistet, aber ausführbar)
ncc module-manager get-module-data  # Discovery-Script ausführen
```

---

✅ **Registry Pattern umgesetzt:**

1. **Alle Commands via Registry:** `cliRegistry.registerCommandsFor "namespace" [commands]`
2. **Interne Commands:** `internal = true;` markiert (versteckt in Hilfe)
3. **Security Parameter:** `permission`, `dangerous`, `requiresSudo` verfügbar
4. **Konsistente Struktur:** `name`, `description`, `script`, `category` erforderlich
5. **Module/Plugins:** Über `module enable/disable` gesteuert
6. **Kategorien:** Testing, Backup, Monitoring, Deployment, API, Web getrennt

---

Wenn du willst, kann ich noch eine **komplette Tabelle erstellen**, die **alle Commands nach Kategorie sortiert**, intern markiert vs. öffentlich, und mit **Beispiel-Syntax** für Flags und Optionen.
Willst du, dass ich das mache?
