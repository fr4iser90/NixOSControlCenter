[4 tools called]

## **Submodule-Analyse & Migrationsplan**

Nach Analyse des NCC-Systems gibt es **5 Submodule** die zu Components konvertiert werden müssen:

---

## **🎯 ZU MIGRieren: 5 Submodule**

### **Gruppe 1: system-manager Submodule (3 Stück)**

#### **1. `system-checks` → Component**
**Aktuell:** `core/management/system-manager/submodules/system-checks/`
**Größe:** Sehr umfangreich (prebuild/postbuild checks)

**Migrations-Strategie:**
```bash
# VON:
core/management/system-manager/submodules/system-checks/
├── default.nix
├── options.nix
├── config.nix
├── lib/
├── scripts/
└── prebuild/ + postbuild/

# NACH:
core/management/system-manager/
├── default.nix          # Importiert system-checks component
├── options.nix          # system-manager.enableChecks Option
├── components/
│   └── system-checks/   # ← NEU: Reine Component
│       ├── handlers.nix # Check-Logik
│       ├── processors.nix
│       ├── prebuild/    # Bleibt erhalten
│       └── postbuild/   # Bleibt erhalten
└── config.nix           # Aktiviert component basierend auf enableChecks
```

#### **2. `system-logging` → Component**
**Aktuell:** `core/management/system-manager/submodules/system-logging/`
**Funktion:** Sammelt System-Informationen

**Migrations-Strategie:**
```bash
# VON:
core/management/system-manager/submodules/system-logging/

# NACH:
core/management/system-manager/components/
└── system-logging/      # ← Reine Component
    ├── collectors/      # Bleibt (Daten sammeln)
    ├── handlers/        # Bleibt (Verarbeitung)
    └── processors.nix   # Neue Datei für Logik
```

#### **3. `system-update` → Component**
**Aktuell:** `core/management/system-manager/submodules/system-update/`
**Funktion:** System-Updates

**Migrations-Strategie:**
```bash
# VON:
core/management/system-manager/submodules/system-update/

# NACH:
core/management/system-manager/components/
└── system-update/       # ← Reine Component
    ├── handlers/
    └── update-logic.nix
```

---

### **Gruppe 2: nixos-control-center Submodule (2 Stück)**

#### **4. `cli-formatter` → Component**
**Aktuell:** `core/management/nixos-control-center/submodules/cli-formatter/`
**Größe:** Sehr umfangreich (volle UI-Library)

**Migrations-Strategie:**
```bash
# VON:
core/management/nixos-control-center/submodules/cli-formatter/

# NACH:
core/management/nixos-control-center/
├── components/
│   └── cli-formatter/   # ← Reine Component
│       ├── core/        # Bleibt (UI Grundlagen)
│       ├── components/  # Bleibt (UI Components)
│       ├── interactive/ # Bleibt (TUI Funktionen)
│       └── status/      # Bleibt (Status Anzeigen)
└── default.nix          # Importiert cli-formatter component
```

#### **5. `cli-registry` → Component**
**Aktuell:** `core/management/nixos-control-center/submodules/cli-registry/`
**Funktion:** Command-Registration

**Migrations-Strategie:**
```bash
# VON:
core/management/nixos-control-center/submodules/cli-registry/

# NACH:
core/management/nixos-control-center/components/
└── cli-registry/        # ← Reine Component
    ├── lib/             # Bleibt (Registry Logik)
    ├── cli/             # Bleibt (Command Preview)
    └── scripts/         # Bleibt (Script Generierung)
```

---

## **🔄 Migrations-Schritte**

### **Schritt 1: Verzeichnis-Struktur anpassen**
```bash
# Alte Submodule-Verzeichnisse verschieben
mv core/management/system-manager/submodules/* core/management/system-manager/components/
mv core/management/nixos-control-center/submodules/* core/management/nixos-control-center/components/

# Submodule-Verzeichnisse löschen
rmdir core/management/*/submodules/
```

### **Schritt 2: Module-Dateien entfernen**
**Zu entfernen aus jedem Submodul:**
- ❌ `default.nix` (war Entry Point)
- ❌ `options.nix` (war Modul-Config)
- ✅ `config.nix` → zu `handlers/${name}.nix`
- ✅ `api.nix` → zu `api/${name}.nix` (falls vorhanden)
- ✅ `commands.nix` → zu `scripts/${name}-commands.nix`

### **Schritt 3: Hauptmodule aktualisieren**

**system-manager/default.nix:**
```nix
imports = [
  ./options.nix
  ./config.nix
  # NEU: Components importieren statt Submodule
  ./components/system-checks/handlers.nix
  ./components/system-logging/handlers.nix
  ./components/system-update/handlers.nix
];
```

**nixos-control-center/default.nix:**
```nix
imports = [
  ./options.nix
  ./config.nix
  # NEU: Components importieren
  ./components/cli-formatter/core/default.nix
  ./components/cli-registry/lib/default.nix
];
```

### **Schritt 4: Options anpassen**

**system-manager/options.nix:**
```nix
options.systemConfig.core.management.system-manager = {
  # Statt separater Submodule-Options:
  enableChecks = mkOption {
    type = types.bool;
    default = true;
    description = "Enable system checks component";
  };
  enableLogging = mkOption {
    type = types.bool;
    default = true;
    description = "Enable system logging component";
  };
  enableUpdates = mkOption {
    type = types.bool;
    default = true;
    description = "Enable system update component";
  };
};
```

---

## **🎯 Neue Detection-Logic**

**Neues Discovery-Script:**
```bash
# NUR echte Module finden (keine Components/Submodule)
find "$MODULES_BASE" -maxdepth 2 -name "default.nix" -type f |
  while read -r file; do
    dir=$(dirname "$file")
    
    # MUSS options.nix haben (sonst Component)
    if [[ ! -f "$dir/options.nix" ]]; then
      continue
    fi
    
    # MUSS _module.metadata haben
    if ! grep -q "_module.metadata" "$dir/default.nix"; then
      continue
    fi
    
    # MUSS category in metadata haben
    if ! grep -q "category.*core\\|modules" "$dir/default.nix"; then
      continue
    fi
    
    # Das ist ein echtes MODUL!
    register_module "$dir"
  done
```

---

## **📊 Erwartetes Ergebnis**

**VOR Migration:**
- 241 "Module" (inkl. alle Unterverzeichnisse)

**NACH Migration:**
- ~15 echte Module
- ~200 Components (nicht als Module gezählt)

**Das eliminiert die falschen Detections komplett!**

---

**Willst du, dass ich die Migration durchführe?** (Dann zu Agent Mode wechseln)

Oder soll ich zuerst ein Test-Discovery-Script erstellen, das die neue Logik demonstriert? 🛠️