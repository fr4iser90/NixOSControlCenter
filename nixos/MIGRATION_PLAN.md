# Migrationsplan: terminal-ui → cli-formatter (Features → Core)

## 🎯 Ziel

1. **Umbenennung:** `terminal-ui` → `cli-formatter`
2. **Verschiebung:** `features/terminal-ui/` → `core/cli-formatter/`
3. **Referenzen:** Alle `config.features.terminal-ui` → `config.core.cli-formatter`

---

## 📋 Schritt-für-Schritt Plan

### Phase 1: Vorbereitung

#### 1.1 Backup erstellen
```bash
# Backup des aktuellen Zustands
git add -A
git commit -m "Backup before terminal-ui → cli-formatter migration"
```

#### 1.2 Alle Referenzen finden
```bash
# Finde alle Dateien mit terminal-ui
grep -r "terminal-ui" nixos/ --files-with-matches
```

---

### Phase 2: Dateien verschieben

#### 2.1 Ordnerstruktur verschieben
```bash
# Verschiebe von features/ nach core/
mv nixos/features/terminal-ui nixos/core/cli-formatter
```

**Dateien die verschoben werden:**
- `nixos/features/terminal-ui/` → `nixos/core/cli-formatter/`
  - `default.nix`
  - `colors.nix`
  - `core/` (Ordner)
  - `components/` (Ordner)
  - `interactive/` (Ordner)
  - `status/` (Ordner)

---

### Phase 3: Core-Integration

#### 3.1 `core/default.nix` erweitern
**Datei:** `nixos/core/default.nix`

**Änderung:**
```nix
{
  imports = [
    # Core modules
    ./boot
    ./hardware
    ./network
    ./system
    ./user
    ./config
    ./cli-formatter  # NEU
  ];
}
```

---

### Phase 4: Feature-System anpassen

#### 4.1 `features/default.nix` anpassen
**Datei:** `nixos/features/default.nix`

**Änderungen:**
1. **Entfernen aus `featureModuleMap`:**
   ```nix
   featureModuleMap = {
     # "terminal-ui" = ./terminal-ui;  # ENTFERNEN
     "command-center" = ./command-center;
     # ...
   };
   ```

2. **Entfernen aus `terminalUIFirst`:**
   ```nix
   # ALT:
   terminalUIFirst = if hasAnyFeature && lib.elem "terminal-ui" allFeatures then [ ./terminal-ui ] else [];
   otherModules = lib.filter (m: toString m != toString ./terminal-ui) featureModules;
   
   # NEU:
   # terminalUIFirst entfernen - cli-formatter ist jetzt in Core
   imports = featureModules;  # Einfacher, keine Sonderbehandlung nötig
   ```

3. **Entfernen aus Auto-Enable:**
   ```nix
   config = {
     # features.terminal-ui.enable = lib.mkIf (lib.elem "terminal-ui" allFeatures) true;  # ENTFERNEN
     # cli-formatter ist jetzt in Core, kein enable nötig
     
     nix.settings.experimental-features = [ "nix-command" "flakes" ];
   };
   ```

---

#### 4.2 `features/metadata.nix` anpassen
**Datei:** `nixos/features/metadata.nix`

**Änderungen:**
1. **Entfernen aus Dependencies:**
   ```nix
   {
     features = {
       "system-updater" = {
         dependencies = [ "command-center" ];  # "terminal-ui" entfernen
         conflicts = [];
       };
       "system-checks" = {
         dependencies = [];  # "terminal-ui" entfernen
         conflicts = [];
       };
       "system-logger" = {
         dependencies = [];  # "terminal-ui" entfernen
         conflicts = [];
       };
       "ssh-client-manager" = {
         dependencies = [];  # "terminal-ui" entfernen
         conflicts = [];
       };
       "ssh-server-manager" = {
         dependencies = [ "command-center" ];  # "terminal-ui" entfernen
         conflicts = [];
       };
       "command-center" = {
         dependencies = [];  # "terminal-ui" entfernen (ist jetzt Core)
         conflicts = [];
       };
       "system-discovery" = {
         dependencies = [ "command-center" ];  # "terminal-ui" entfernen
         conflicts = [];
       };
       # "terminal-ui" = { ... };  # ENTFERNEN (ist jetzt Core)
     };
   }
   ```

---

### Phase 5: Module-Dateien anpassen

#### 5.1 `core/cli-formatter/default.nix` anpassen
**Datei:** `nixos/core/cli-formatter/default.nix`

**Änderungen:**
1. **Options-Pfad ändern:**
   ```nix
   # ALT:
   options.features.terminal-ui = { ... };
   
   # NEU:
   options.core.cli-formatter = { ... };
   ```

2. **Config-Pfad ändern:**
   ```nix
   # ALT:
   cfg = config.features.terminal-ui;
   config = {
     features.terminal-ui.api = apiValue;
   };
   
   # NEU:
   cfg = config.core.cli-formatter;
   config = {
     core.cli-formatter.api = apiValue;
   };
   ```

3. **Enable-Option entfernen (optional):**
   ```nix
   # Core = immer aktiv, enable-Option nicht nötig
   # Aber: Kann für Kompatibilität bleiben
   ```

---

#### 5.2 `core/config/default.nix` anpassen
**Datei:** `nixos/core/config/default.nix`

**Änderungen:**
1. **Import-Pfad ändern:**
   ```nix
   # ALT:
   colors = import ../../features/terminal-ui/colors.nix;
   core = import ../../features/terminal-ui/core { inherit lib colors; config = {}; };
   status = import ../../features/terminal-ui/status { inherit lib colors; config = {}; };
   
   # NEU:
   colors = import ../cli-formatter/colors.nix;
   core = import ../cli-formatter/core { inherit lib colors; config = {}; };
   status = import ../cli-formatter/status { inherit lib colors; config = {}; };
   ```

---

### Phase 6: Feature-Module anpassen

#### 6.1 Alle Features die `terminal-ui` verwenden

**Dateien die angepasst werden müssen:**
1. `nixos/features/command-center/default.nix`
2. `nixos/features/system-checks/**/*.nix`
3. `nixos/features/system-logger/**/*.nix`
4. `nixos/features/system-updater/**/*.nix`
5. `nixos/features/ssh-client-manager/**/*.nix`
6. `nixos/features/ssh-server-manager/**/*.nix`
7. `nixos/features/system-discovery/**/*.nix`

**Änderung in allen Dateien:**
```nix
# ALT:
ui = config.features.terminal-ui.api;

# NEU:
formatter = config.core.cli-formatter.api;
# Oder kurz:
fmt = config.core.cli-formatter.api;
```

**Oder Variable umbenennen:**
```nix
# ALT:
let
  ui = config.features.terminal-ui.api;
in {
  ${ui.messages.info "..."}
}

# NEU:
let
  fmt = config.core.cli-formatter.api;
in {
  ${fmt.messages.info "..."}
}
```

---

### Phase 7: Globale Suche & Replace

#### 7.1 IDE Global Refactoring

**Suche & Replace:**
1. **Pfad-Referenzen:**
   - `features.terminal-ui` → `core.cli-formatter`
   - `features/terminal-ui` → `core/cli-formatter`
   - `terminal-ui` → `cli-formatter` (in Pfaden)

2. **Config-Referenzen:**
   - `config.features.terminal-ui` → `config.core.cli-formatter`
   - `cfg.features.terminal-ui` → `cfg.core.cli-formatter`

3. **Variable-Namen (optional):**
   - `ui` → `fmt` oder `formatter` (optional, für Klarheit)

4. **Kommentare:**
   - `terminal-ui` → `cli-formatter` (in Kommentaren)
   - `Terminal-UI` → `CLI-Formatter` (in Kommentaren)

---

### Phase 8: Dokumentation anpassen

#### 8.1 Dokumentationsdateien

**Dateien die angepasst werden müssen:**
1. `nixos/features/system-discovery/ARCHITECTURE.md`
   - Alle `terminal-ui` → `cli-formatter`
   - Alle `config.features.terminal-ui` → `config.core.cli-formatter`

2. `nixos/STRUCTURE.md`
   - `terminal-ui` → `cli-formatter`
   - Core-Sektion erweitern

3. `nixos/STRUCTURE_ANALYSIS.md`
   - Alle Referenzen aktualisieren

4. `nixos/CORE_MIGRATION_ANALYSIS.md`
   - Alle Referenzen aktualisieren

5. `nixos/TERMINAL_UI_NAMING.md`
   - Datei umbenennen zu `CLI_FORMATTER_NAMING.md`
   - Alle Referenzen aktualisieren

---

### Phase 9: Testing

#### 9.1 Build-Test
```bash
# Test ob System baut
sudo nixos-rebuild build --flake /etc/nixos#Gaming
```

#### 9.2 Feature-Tests
```bash
# Test ob alle Features funktionieren
ncc help
ncc system-update
ncc discover
# etc.
```

---

## 📝 Checkliste

### Dateien die verschoben werden:
- [ ] `nixos/features/terminal-ui/` → `nixos/core/cli-formatter/`

### Dateien die angepasst werden müssen:

#### Core:
- [ ] `nixos/core/default.nix` - Import hinzufügen
- [ ] `nixos/core/cli-formatter/default.nix` - Options/Config-Pfade ändern
- [ ] `nixos/core/config/default.nix` - Import-Pfade ändern

#### Features:
- [ ] `nixos/features/default.nix` - terminal-ui entfernen
- [ ] `nixos/features/metadata.nix` - Dependencies entfernen
- [ ] `nixos/features/command-center/default.nix`
- [ ] `nixos/features/system-checks/**/*.nix`
- [ ] `nixos/features/system-logger/**/*.nix`
- [ ] `nixos/features/system-updater/**/*.nix`
- [ ] `nixos/features/ssh-client-manager/**/*.nix`
- [ ] `nixos/features/ssh-server-manager/**/*.nix`
- [ ] `nixos/features/system-discovery/**/*.nix`

#### Dokumentation:
- [ ] `nixos/features/system-discovery/ARCHITECTURE.md`
- [ ] `nixos/STRUCTURE.md`
- [ ] `nixos/STRUCTURE_ANALYSIS.md`
- [ ] `nixos/CORE_MIGRATION_ANALYSIS.md`
- [ ] `nixos/TERMINAL_UI_NAMING.md` → `CLI_FORMATTER_NAMING.md`

---

## 🔍 Globale Suche & Replace (IDE)

### Pattern 1: Config-Referenzen
```
Find: config\.features\.terminal-ui
Replace: config.core.cli-formatter
```

### Pattern 2: Pfad-Referenzen
```
Find: features/terminal-ui
Replace: core/cli-formatter
```

### Pattern 3: Feature-Name
```
Find: "terminal-ui"
Replace: "cli-formatter"
```

### Pattern 4: Options-Pfad
```
Find: features\.terminal-ui
Replace: core.cli-formatter
```

### Pattern 5: Variable-Namen (optional)
```
Find: \bui\b = config\.features\.terminal-ui
Replace: fmt = config.core.cli-formatter
```

---

## ⚠️ Wichtige Hinweise

1. **Reihenfolge:** Erst Dateien verschieben, dann Referenzen ändern
2. **Backup:** Immer Backup vor Migration
3. **Testing:** Nach jeder Phase testen
4. **Variable-Namen:** `ui` → `fmt` ist optional, aber empfohlen
5. **Enable-Option:** Kann in Core bleiben für Kompatibilität, wird aber nicht verwendet

---

## 🎯 Zusammenfassung

**Schritte:**
1. ✅ Backup erstellen
2. ✅ Ordner verschieben: `features/terminal-ui` → `core/cli-formatter`
3. ✅ `core/default.nix` erweitern
4. ✅ `features/default.nix` anpassen
5. ✅ `features/metadata.nix` anpassen
6. ✅ `core/cli-formatter/default.nix` anpassen
7. ✅ `core/config/default.nix` anpassen
8. ✅ Alle Feature-Module anpassen (7 Features)
9. ✅ Globale Suche & Replace
10. ✅ Dokumentation anpassen
11. ✅ Testing

**Geschätzte Dateien:** ~30-40 Dateien

**Geschätzte Zeit:** 1-2 Stunden (mit IDE Global Refactoring)

