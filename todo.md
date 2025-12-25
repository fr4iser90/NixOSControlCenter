# NCC Module Refactoring TODO - MODULE_TEMPLATE Konformität

## 🚨 **KRITISCHE API-PROBLEME (sofort beheben)**

### **Hardcoded moduleName → baseNameOf ./. ändern**
**Status:** 7 Module müssen geändert werden
- [x] `homelab-manager`: `moduleName = "homelab-manager"` → `moduleName = baseNameOf ./.` ✅
- [x] `ssh-client-manager`: `moduleName = "ssh-client-manager"` → `moduleName = baseNameOf ./.` ✅
- [x] `bootentry-manager`: `moduleName = "bootentry-manager"` → `moduleName = baseNameOf ./.` ✅
- [x] `vm`: `moduleName = "vm"` → `moduleName = baseNameOf ./.` ✅
- [x] `ssh-server-manager`: `moduleName = "ssh-server-manager"` → `moduleName = baseNameOf ./.` ✅
- [x] `hackathon`: `moduleName = "hackathon"` → `moduleName = baseNameOf ./.` ✅
- [x] `ai-workspace`: `moduleName = "ai-workspace"` → `moduleName = baseNameOf ./.` ✅

### **Hardcoded Pfad-Zugriffe → API-basiert ändern**
**Status:** Mehrere Module greifen hardcoded auf systemConfig zu
- [x] `homelab-manager`: `systemConfig.homelab.swarm` → `cfg.swarm` und API-Args verwenden ✅
- [x] `ssh-client-manager`: `systemConfig.modules.security.ssh-client-manager` → `moduleConfig.configPath` und API-Args verwenden ✅
- [x] `system-manager`: Behält `config.${configPath}` (Chicken-Egg Problem bei Core-Modulen) ✅
- [x] Alle Module: hardcoded Pfade in commands.nix durch `moduleConfig` ersetzen ✅

## 📁 **STRUKTUR-PROBLEME (Template-Konformität)**

### **Falsche Verzeichnis-Struktur**
**Status:** Viele Module haben Dateien im Root statt in korrekten Verzeichnissen

#### **homelab-manager (scripts/ sollte handlers/ sein)**
- [x] `scripts/homelab-create.nix` → `handlers/homelab-create.nix` ✅
- [x] `scripts/homelab-fetch.nix` → `handlers/homelab-fetch.nix` ✅
- [x] Pfad-Updates in default.nix und anderen Dateien ✅
homelab-manager/
├── handlers/                # ✅ Business logic orchestration
│   ├── homelab-create.nix    # ✅ Implementiert
│   └── homelab-fetch.nix     # ✅ Implementiert
└── scripts/                  # 🗑️ Leere Platzhalter entfernt

#### **ssh-client-manager (jetzt vollständig korrigiert)**
- [x] Alle Handler sind bereits in `handlers/` ✅
- [x] Scripts sind bereits in `scripts/` ✅
- [x] Imports in default.nix korrigiert - nicht existierende Dateien entfernt ✅

#### **bootentry-manager (Analyse abgeschlossen)**
- [ ] `providers/` → `handlers/` verschieben (Business-Logic für Bootloader)
- [ ] `commands.nix` erstellen (NCC-Commands für Boot-Management)
- [ ] `scripts/` Verzeichnis erstellen für Executables
- [ ] lib/ Struktur ist korrekt ✅

#### **vm (prüfen)**
- [ ] lib/ Struktur überprüfen
- [ ] Eventuell testing/ zu tests/ umbenennen

#### **ssh-server-manager (prüfen)**
- [ ] scripts/ zu handlers/ verschieben?
- [ ] Alle Handler-Dateien in handlers/ konsolidieren

#### **hackathon (prüfen)**
- [ ] hackathon-*.nix Dateien zu handlers/ verschieben?

#### **ai-workspace (prüfen)**
- [ ] containers/ und schemas/ Struktur überprüfen
- [ ] Eventuell zu submodules/ umstrukturieren

## 🔧 **TECHNISCHE VERBESSERUNGEN**

### **API-Konsistenz**
**Status:** Einige Module verwenden API, andere hardcoded
- [ ] Alle Module: `getModuleConfig` statt hardcoded Pfade verwenden
- [ ] Alle Module: `getModuleApi` statt direkter API-Zugriffe
- [ ] Alle Module: `moduleConfig` Parameter in options.nix, commands.nix, config.nix verwenden

### **Metadata-Konsistenz**
**Status:** Einige Module haben unvollständige metadata
- [ ] Alle Module: `stability` und `version` in _module.metadata hinzufügen
- [ ] Alle Module: subcategory korrekt setzen

## ✅ **BEREITS KONFORM (Referenz-Module)**
- [x] `lock-manager`: Vollständig refactored ✅
- [x] `system-manager`: API-konform ✅
- [x] `nixos-control-center`: API-konform ✅
- [x] **ALLE `core/*` Module**: API-konform ✅ (base/, management/, alle verwenden `baseNameOf ./.`)
  - **Strukturell**: `system-manager` und `module-manager` perfekt TEMPLATE-konform ✅
  - **Strukturell**: `base/*` Module haben funktionale Struktur ✅ (vereinfacht für core Module)
    - `audio`: providers/ (funktional, könnte aber collectors/ werden)
    - `boot`: bootloaders/ (funktional, könnte handlers/ werden)
    - `desktop`: funktionale Unterteilung (environments/, display-managers/, etc.)
    - `hardware`: funktionale Unterteilung (cpu/, gpu/, memory/)
    - `network`: lib/ + recommendations/ (könnte processors/ werden)
    - `packages`: modules/ + presets/ (könnte submodules/ werden)
    - `user`: home-manager/ (funktionale rollenbasierte Struktur)
- [x] Alle `system-manager` Submodules: API-konform ✅

### **Optionale Core-Struktur-Verbesserungen**
**Status:** Einige schon gemacht!
- [x] `desktop/`: environments/, display-managers/, themes/ → components/ ✅ **FERTIG!**
- [ ] `audio/providers/` → `audio/collectors/` (TEMPLATE-konform)
- [ ] `boot/bootloaders/` → `boot/providers/` (klarere Benennung)
- [ ] `network/recommendations/` → `network/processors/` (TEMPLATE-konform)
- [ ] `packages/modules/` + `packages/presets/` → `packages/submodules/` (konsolidieren)

## 🎯 **PRIORITÄT**
1. **Hardcoded moduleName → baseNameOf ./.** (einfach, großer Impact)
2. **Hardcoded Pfade → API-basiert** (mittel, großer Impact)
3. **Struktur-Probleme beheben** (aufwändig, aber wichtig für Wartbarkeit)

## 📋 **TESTING NACH REFACTORING**
Nach jeder Änderung:
- [ ] `nix-instantiate` auf default.nix testen
- [ ] `ncc help` funktioniert
- [ ] Commands sind verfügbar
- [ ] Keine Linter-Fehler
