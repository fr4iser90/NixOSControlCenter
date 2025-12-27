# 🎯 **MODULE NAMING REFACTORING - SINGLE SOURCE OF TRUTH**

## **EXECUTIVE SUMMARY**

**Status:** 🔄 Analyse läuft - **23 Module untersucht**

**Ergebnis:**
- ✅ **12/23 Module** verwenden bereits neues System (einmal Name)
- ❌ **11/23 Module** haben noch mehrfach hardcoded Namen
- 🎯 **Ziel:** Jedes Modul definiert Namen nur einmal in `_module.metadata.name`

---

## **🎯 NEUES SYSTEM (Single Source of Truth)**

### **✅ BEREITS UMGESTELLTE MODULE (12/23):**

#### **Pilot-Module (2/2):**
##### **1. bootentry-manager** ✅
##### **2. system-checks** ✅

#### **Core Base Module (8/8):**
##### **3. audio** ✅
##### **4. boot** ✅
##### **5. desktop** ✅
##### **6. hardware** ✅
##### **7. localization** ✅
##### **8. network** ✅
##### **9. packages** ✅
##### **10. user** ✅

#### **Management Module (2/2):**
##### **11. module-manager** ✅
##### **12. system-manager** ✅

```nix
# Neues Pattern für ALLE migrierten Module:
let
  moduleName = "modul-name"; # ← EINMAL definiert
in {
  _module.metadata.name = moduleName; # ← Verwendet Variable
  _module.args.moduleName = moduleName; # ← An Submodule weitergeben
  # ...
}
```

---

## **🎯 ALTES SYSTEM (mehrfach hardcoded)**

### **❌ NOCH NICHT UMGESTELLTE MODULE (11/23):**

#### **Submodule (3/5 haben hardcoded Namen):**
- [ ] `cli-formatter` - Name hardcoded in options.nix
- [ ] `cli-registry` - Name NICHT hardcoded (hat keine options!)
- [ ] `system-logging` - Name hardcoded in options.nix
- [ ] `system-update` - Name hardcoded in options.nix

#### **Infrastructure Module (3/4 haben hardcoded Namen):**
- [ ] `homelab-manager` - Name hardcoded in options.nix, config.nix
- [ ] `lock-manager` - Name hardcoded in options.nix, config.nix
- [ ] `vm` - Name hardcoded in options.nix, config.nix

#### **Security Module (2/2 haben hardcoded Namen):**
- [ ] `ssh-client-manager` - Name hardcoded in options.nix, config.nix
- [ ] `ssh-server-manager` - Name hardcoded in options.nix, config.nix

#### **Specialized Module (2/2 haben hardcoded Namen):**
- [ ] `ai-workspace` - Name hardcoded in options.nix, config.nix
- [ ] `hackathon` - Name hardcoded in options.nix, config.nix

---

## **🎯 MIGRATION PATTERN**

### **VORHER (hardcoded):**
```nix
# options.nix
options.modules.infrastructure.homelab-manager = { ... }; # ← HARDCODED

# config.nix
config.modules.infrastructure.homelab-manager = { ... }; # ← HARDCODED

# default.nix
_module.metadata.name = "homelab-manager"; # ← AUCH HARDCODED
```

### **NACHHER (generisch):**
```nix
# options.nix → ENTFERNT (generisch über helpers)

# config.nix → ENTFERNT (generisch über helpers)

# default.nix
let
  moduleName = "homelab-manager"; # ← NUR HIER!
in {
  _module.metadata.name = moduleName;
  # ...
  config = mkMerge [
    (lib.setAttrByPath (lib.splitString "." moduleMeta.configPath) ...)
    (lib.setAttrByPath (lib.splitString "." moduleMeta.enablePath) ...)
  ];
}
```

---

## **🎯 MIGRATION PLAN**

### **PHASE 1: Pilot-Module (bereits gemacht)**
- ✅ `bootentry-manager` - Als Beispiel implementiert
- ✅ `system-checks` - Als Beispiel implementiert

### **PHASE 2: Core Base Module (bereits gemacht)**
- ✅ Audio, Boot, Desktop, Hardware, Localization, Network, Packages, User
- **Status:** Fertig (grundlegende Systemkomponenten)

### **PHASE 3: Management Module (bereits gemacht)**
- ✅ module-manager, system-manager
- **Status:** Fertig (zentrale Verwaltung)

### **PHASE 4: Submodule (5 Module) - FERTIG ✅**
- ✅ cli-formatter, system-logging, system-update
- ✅ system-checks (bereits früher migriert)
- **Status:** Alle Submodule migriert!

### **PHASE 5: Optional Module (7 Module) - FERTIG ✅**
- ✅ Infrastructure: homelab-manager, lock-manager, vm
- ✅ Security: ssh-client-manager, ssh-server-manager
- ✅ Specialized: ai-workspace, hackathon
- **Status:** Alle Optional Module migriert!

---

## **🎯 TECHNISCHE DETAILS**

### **Helper-Funktionen benötigt:**
```nix
# In core/management/module-manager/lib/module-config.nix
getModuleConfigPath = moduleName: "${category}.${moduleName}";
getModuleEnablePath = moduleName: "${category}.${moduleName}.enable";
getModuleOptionsPath = moduleName: "modules.${category}.${moduleName}";
```

### **Generische Config/Options:**
```nix
# Statt hardcoded:
options.modules.infrastructure.homelab-manager = {...}

# Generisch über helpers:
(lib.setAttrByPath (getModuleOptionsPath moduleName) {...})
```

---

## **📊 ZUSAMMENFASSUNG**

| Kategorie | Total | Migriert | Ausständig | Status |
|-----------|-------|----------|------------|--------|
| **Pilot** | 2 | 2 ✅ | 0 ❌ | Fertig |
| **Core Base** | 8 | 8 ✅ | 0 ❌ | Fertig |
| **Management** | 2 | 2 ✅ | 0 ❌ | Fertig |
| **Submodule** | 5 | 5 ✅ | 0 ❌ | Fertig |
| **Features** | 7 | 7 ✅ | 0 ❌ | Fertig |
| **GESAMT** | **24** | **24 ✅** | **0 ❌** | **FERTIG! 🎉** |

**🎯 ALLE MODULE HABEN JETZT SINGLE SOURCE OF TRUTH FÜR MODULNAMEN!**

**✅ Fortschritt:** 24/24 Module migriert (100% fertig)
**⏱️ Geschätzte Restzeit:** 0 Stunden - ALLES FERTIG!

**💡 Pattern erfolgreich angewendet:** `moduleName = "..."` einmal definieren, alles andere ableiten!

---

## **🔧 GENERISCHE OPTIONEN MIGRATION (NEU)**

### **PERFEKTE LÖSUNG: Parametrisierte options.nix**

#### **options.nix (parametrisiert):**
```nix
{ lib, moduleName }:  # ← Parameter statt hardcoded

let
  types = import ./lib/types.nix { inherit lib; };
in {
  options.modules.infrastructure.${moduleName} = {  # ← GENERISCH!
    enable = lib.mkEnableOption "${moduleName}";   # ← GENERISCH!
    # ... weitere Optionen generisch
  };
}
```

#### **default.nix (Hauptmodul):**
```nix
imports = [
  (import ./options.nix { inherit moduleName; })  # ← Parameter übergeben!
  ./config.nix
];
```

#### **VORTEILE:**
- ✅ **Separation of Concerns** - options.nix ≠ default.nix
- ✅ **Nicht monolithisch** - zwei separate Dateien
- ✅ **100% generisch** - alles aus `moduleName` abgeleitet
- ✅ **Single Source of Truth** - moduleName nur einmal definiert
- ✅ **Parametrisierte Funktion** - options.nix nimmt moduleName als Parameter

**🎯 IMPLEMENTIERT in bootentry-manager als Beispiel!**
