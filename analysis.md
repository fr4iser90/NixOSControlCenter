# 🔍 Core vs. Modules – API-Härtung & Generifizierung

## 📋 Analyse-Ergebnisse: Architektur-Probleme identifiziert

### ❌ KRITISCHE HARDCOGINGS (Module verstoßen gegen Generizität)

#### 1. **Feste Core-API-Pfade in Modules** (21+ Verstöße)
**Problem**: Module greifen direkt auf `config.core.management.system-manager.submodules.*` zu

**Beispiele**:
```
# nixos/modules/security/ssh-server-manager/default.nix:8
commandCenter = config.core.management.system-manager.submodules.cli-registry;

# nixos/modules/security/ssh-server-manager/default.nix:68
core.management.system-manager.submodules.cli-formatter.components.ssh-status = {

# nixos/modules/infrastructure/homelab-manager/default.nix:70
core.management.system-manager.submodules.cli-registry.commands = [...]
```

**Betroffene Dateien**: 13+ Module-Scripts verwenden feste Pfade

**Konsequenz**: Module sind nicht mehr generisch, feste Abhängigkeit von Core-Struktur

#### 2. **Inkonsistente API-Funktionen** (getModuleApi)
**Problem**: Magische Übersetzung zwischen Build-Time und Runtime  (Funktioniert aber scheinbar?)

```nix
# nixos/core/management/module-manager/lib/module-config.nix:79-92
if (builtins.tryEval builtins.derivation).success then
  # Build-Time: Direktes API import
  import "${targetModule.path}/api.nix" { inherit lib; }
else
  # Runtime: String return
  apiPath + ".api";
```

**Probleme**:
- Nicht-deterministisch (`builtins.tryEval builtins.derivation`)
- Inkonsistente Rückgabewerte (Objekt vs. String)
- Verwirrende Semantik

#### 3. **Single Source of Truth: Discovery** (NICHT Metadata)
**Architektur-Entscheidung**: Pfad-Generierung erfolgt aus Verzeichnisstruktur via Discovery

**Aktuelle Discovery-Logik** (RICHTIG SO):
```nix
# nixos/core/management/module-manager/lib/discovery.nix:30-34
category = "${rootCategory}.${currentCategory}";  # AUS VERZEICHNISSTRUKTUR!
configPath = "${rootCategory}.${currentCategory}";  # AUS VERZEICHNISSTRUKTUR!
apiPath = "${rootCategory}.${currentCategory}";     # AUS VERZEICHNISSTRUKTUR!
```

**_module.metadata Zweck**: Nur Meta-Informationen (description, version, etc.), NICHT Pfade!

**Beispiel-Problem BEHOBEN ✅**:
- Modul liegt in: `modules/infrastructure/bootentry-manager/`
- Discovery generiert: `configPath = "modules.infrastructure.bootentry-manager"` ✅
- config.nix verwendet: `systemConfig.modules.infrastructure.bootentry-manager` ✅
- options.nix definiert: `options.modules.infrastructure.bootentry-manager` ✅
- default.nix verwendet: `getModuleConfig "bootentry-manager"` ✅

**Konsequenz**: Konsistente Namensgebung - Modul folgt Discovery-Pfaden

**Architektur-Implikation**: Module können NICHT frei verschoben werden, Pfade ändern sich automatisch

**Lösung**:
1. Konsistente Namensgebung: Ordnername = Modulname = Options-Pfad
2. Alle Module müssen Discovery-Pfade verwenden, keine Hardcodings
3. _module.metadata nur für Meta-Infos (description, version, etc.)

#### 4. **Redundante Modulnamen-Definitionen** (15+ Stellen)
**Problem**: `moduleName = "xyz"` wird manuell definiert statt aus Discovery

**Lösung**: Single Source of Truth in default.nix
```nix
# default.nix: Einmalig definieren
_module.args.moduleName = "bootentry-manager";

# config.nix: Als Parameter bekommen
{ config, lib, ..., moduleName, ... }:
let
  moduleMeta = getModuleMetadata moduleName;
```

**Beispiele**:
```
# nixos/core/management/system-manager/config.nix:36
moduleName = "system-manager";

# nixos/modules/infrastructure/homelab-manager/config.nix:12
moduleName = "homelab";
```

#### 5. **Direkte relative Imports zwischen Modulen**
**Problem**: Feste Annahmen über Verzeichnisstruktur

```nix
# nixos/core/management/system-manager/submodules/cli-registry/config.nix:4
configHelpers = import ../../../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
```

#### 6. **Feste Bootloader-Abhängigkeiten**
**Problem**: Module greifen direkt auf andere Core-Module zu

```nix
# nixos/modules/infrastructure/bootentry-manager/default.nix:18-20
selectedProvider = if config.boot.loader.systemd-boot.enable then providers."systemd-boot"
                   else if config.boot.loader.grub.enable then providers.grub
                   else providers."systemd-boot";
```

### ✅ POSITIVE BEFUNDE

#### 1. **Korrekte getModuleConfig-Nutzung**
Viele Module verwenden `getModuleConfig "modulname"` korrekt

#### 2. **Discovery = Single Source of Truth**
Pfade werden konsistent aus Verzeichnisstruktur generiert (beabsichtigte Architektur)

#### 3. **Helper-Funktionen verfügbar**
`getModuleConfig`, `getModuleMetadata`, `getCurrentModuleMetadata` sind implementiert

### 🏗️ ARCHITEKTUR-EMPFEHLUNGEN

#### **1. Sofortige Korrekturen**

**A) Single Source of Truth für Modulnamen**: Variable einmal definieren, überall verwenden
```nix
# default.nix:
let
  moduleName = "bootentry-manager";  # ← NUR HIER definieren!
  moduleMeta = getModuleMetadata moduleName;
  cfg = getModuleConfig moduleName;
in {
  _module.args.moduleName = moduleName;
  _module.metadata.name = moduleName;
  # Generisch: enable-Flag aus Discovery-Pfad
  "${moduleMeta.enablePath}" = mkDefault (cfg.enable or false);
}

# config.nix:
{ ..., moduleName, ... }:  # ← Als Parameter bekommen
let
  moduleMeta = getModuleMetadata moduleName;
```

**B) Namensgebung konsistent machen**: Ordnername = Modulname = Options-Pfad

**B) getModuleApi vereinheitlichen**: Immer konsistente Semantik
```nix
# NEU: Immer String zurückgeben, niemals direkt importieren
getModuleApi = moduleName: (getModuleMetadata moduleName).apiPath + ".api";
```

**C) Core-API-Registry einführen**: Zentralisierte API-Verwaltung
```nix
# NEU: config.core.api.{moduleName}
core.api.cli-formatter = { ... };
core.api.cli-registry = { ... };
```

#### **2. Neue Helper-Funktionen**

**A) getModuleApiPath**: Reine Pfad-Funktion
```nix
getModuleApiPath = moduleName: (getModuleMetadata moduleName).apiPath;
```

**B) getCoreApi**: Sichere Core-API-Zugriffe für Module
```nix
getCoreApi = moduleName: config.core.api.${moduleName};
```

**C) assertGenericity**: Build-Time Validierung
```nix
assertGenericity = modulePath: let
  content = builtins.readFile modulePath;
in if builtins.match "config\.core\." content != null
   then throw "Module ${modulePath} contains hardcoded core references"
   else true;
```

#### **3. Boundary-Klärung**

**Core darf**:
- Feste API-Pfade kennen
- Andere Core-Module direkt referenzieren
- Framework-Logik enthalten

**Modules dürfen NICHT**:
- Feste Core-Pfade verwenden (müssen `getModuleApi`/`getModuleConfig` nutzen)
- Annahmen über Core-Struktur machen
- Relative Imports zwischen Modulen machen
- Inkonsistente Namensgebung verwenden (Ordner ≠ Options-Pfad)

#### **4. Implementierungsplan**

**Phase 1**: Core-API-Registry implementieren
**Phase 2**: Alle festen Core-Referenzen ersetzen
**Phase 3**: Discovery überarbeiten (Metadata-first)
**Phase 4**: getModuleApi vereinheitlichen
**Phase 5**: Tests für Generizität hinzufügen

### 📊 METRIKEN

- **Hardcodings gefunden**: 20+ feste Core-API-Zugriffe (1 eliminiert)
- **Betroffene Module**: 6+ Module (ssh-server-manager, homelab-manager, etc.)
- **Redundante Modulnamen**: 15+ manuelle Definitionen (2 vollständig generisch)
- **Metadata-Verwendung**: 0% (nur Dekoration)
- **API-Inkonsistenzen**: 1 (getModuleApi)

### 🎯 KLARER AKTIONSPLAN

1. **Sofort**: Core-API-Registry implementieren
2. **Dringend**: Alle Module von festen Pfaden befreien
3. **Bald**: Discovery und getModuleApi überarbeiten
4. **Langfristig**: Vollständige Generizität durchsetzen

**Erfolgskriterium**: Konsistente Namensgebung und Pfad-Verwendung in allen Modulen.
