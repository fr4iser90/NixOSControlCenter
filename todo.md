**Exzellente Fragen!** Du hast absolut recht - wir brauchen eine klare Standardisierung. Lass uns das Schema richtig definieren:

## **1. Minimale Requirements für ALLE Module**

**Jedes NCC Modul MUSS haben:**
```json
{
  "type": "modular|monolithic",
  "structure": {
    "default.nix": "string",      // ERFORDERLICH - Entry Point
    "options.nix": "string",      // ERFORDERLICH - Konfiguration
    "_module.metadata": "object"  // ERFORDERLICH - Discovery Data
  },
  "metadata": {
    "name": "string",             // ERFORDERLICH - Eindeutiger Name
    "description": "string",      // ERFORDERLICH - Menschenlesbare Beschreibung
    "category": "string",         // ERFORDERLICH - core|modules
    "version": "string"           // ERFORDERLICH - SemVer
  }
}
```

**Zusätzliche Requirements:**
- ✅ **`default.nix`** muss `_module.metadata` exportieren
- ✅ **`options.nix`** muss `systemConfig.{category}.{name}` definieren
- ✅ **Filesystem-Struktur** muss konsistent sein
- ✅ **API-Namenskonventionen** müssen eingehalten werden

## **2. Schema mit detaillierten Requirements**

**Aktualisiertes modular.json:**
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "type": { "const": "modular" },
    "version": { "pattern": "^\\d+\\.\\d+\\.\\d+$" },
    
    "structure": {
      "type": "object",
      "properties": {
        "default.nix": {
          "type": "string",
          "description": "Entry point - MUSS _module.metadata exportieren"
        },
        "options.nix": {
          "type": "string", 
          "description": "Options - MUSS systemConfig.{category}.{name} definieren"
        },
        "config.nix": {
          "type": "boolean",
          "description": "Implementation - OPTIONAL aber empfohlen"
        },
        "api.nix": {
          "type": "boolean",
          "description": "API exports - OPTIONAL für wiederverwendbare Module"
        },
        "commands.nix": {
          "type": "boolean",
          "description": "CLI commands - OPTIONAL"
        },
        
        "lib/": {
          "type": "object",
          "description": "Shared utilities - OPTIONAL"
        },
        "validators/": {
          "type": "object", 
          "description": "Input validation - OPTIONAL"
        },
        "handlers/": {
          "type": "object",
          "description": "Business logic - OPTIONAL"
        },
        "scripts/": {
          "type": "object",
          "description": "CLI executables - OPTIONAL"
        }
      },
      "required": ["default.nix", "options.nix"]
    },
    
    "metadata": {
      "type": "object",
      "properties": {
        "name": {
          "type": "string",
          "description": "Eindeutiger Modulname (keine Leerzeichen)"
        },
        "description": {
          "type": "string",
          "minLength": 10,
          "description": "Menschenlesbare Beschreibung"
        },
        "category": {
          "enum": ["core", "modules"],
          "description": "Namespace: core (always enabled) | modules (opt-in)"
        },
        "subcategory": {
          "type": "string",
          "description": "Unterkategorie (z.B. 'base', 'infrastructure')"
        },
        "version": {
          "pattern": "^\\d+\\.\\d+\\.\\d+$",
          "description": "SemVer Version"
        },
        "stability": {
          "enum": ["stable", "beta", "alpha", "experimental"],
          "description": "Stabilitätslevel"
        }
      },
      "required": ["name", "description", "category", "version"]
    },
    
    "requirements": {
      "type": "object",
      "properties": {
        "dependencies": {
          "type": "array",
          "items": { "type": "string" },
          "description": "Andere Module die benötigt werden"
        },
        "conflicts": {
          "type": "array", 
          "items": { "type": "string" },
          "description": "Inkompatible Module"
        }
      }
    }
  },
  "required": ["type", "version", "structure", "metadata"]
}
```

## **3. Integration mit MODULE_TEMPLATE.md**

**Das Schema sollte das Template ERWEITERN:**

```markdown
## Module Requirements (AUTOMATISCH VALIDIERT)

### Pflicht-Requirements (SCHEMA-VALIDIERT)
- [x] **`default.nix`** mit `_module.metadata`
- [x] **`options.nix`** mit korrekten Pfaden
- [x] **Metadata** vollständig definiert
- [x] **Filesystem-Struktur** konsistent

### Empfohlene Struktur (TEMPLATE-BASED)
- [ ] `config.nix` für Implementation
- [ ] `api.nix` für Wiederverwendung
- [ ] `lib/` für Utilities
- [ ] `validators/` für Input-Checks
```

## **4. Assertions & Violations Detection**

**Drei Ebenen der Validation:**

### **A) Schema-Level (JSON Schema)**
```nix
# Automatisch beim Discovery
validateModule = modulePath: 
  let
    schema = loadJsonSchema "modular";
    data = extractModuleData modulePath;
  in
  lib.runJsonSchema schema data;
```

### **B) Structural Assertions**
```nix
# Zusätzliche Checks die Schema nicht abdeckt
validateModuleStructure = modulePath:
  let
    hasRequiredFiles = all (f: pathExists "${modulePath}/${f}") 
                         ["default.nix" "options.nix"];
    hasValidMetadata = checkMetadataConsistency modulePath;
    hasCorrectOptions = validateOptionsStructure modulePath;
  in {
    valid = hasRequiredFiles && hasValidMetadata && hasCorrectOptions;
    violations = collectViolations [hasRequiredFiles hasValidMetadata hasCorrectOptions];
  };
```

### **C) Runtime Assertions**
```nix
# In config.nix - NixOS Module System
{
  assertions = [
    {
      assertion = cfg.enable -> (cfg.someRequiredOption != null);
      message = "someRequiredOption must be set when module is enabled";
    }
  ];
}
```

## **5. Ziel: Vollständige Automatisierung**

**Workflow soll so aussehen:**
```
1. Neues Modul erstellen (Template kopieren)
2. Dateien ausfüllen
3. nixos-rebuild → Automatische Discovery
4. Schema-Validation läuft automatisch
5. Violations werden reported
6. Bei Erfolg: Modul ist verfügbar
```

**Detection & Reporting:**
```bash
# Bei Violations
❌ Module 'my-module' invalid:
   - Missing required file: options.nix
   - Invalid metadata: missing 'description'
   - Options path incorrect: expected 'systemConfig.modules.my-module'

# Bei Success  
✅ Module 'my-module' validated and registered
```

## **6. Gleichbehandlung Core vs Modules**

**Alle Module folgen denselben Regeln:**
- ✅ **Selbe Struktur** (nur Pfad unterschiedlich)
- ✅ **Selbe Metadata-Requirements**
- ✅ **Selbe Validation**
- ✅ **Selbe API-Patterns**

**Unterschied nur in:**
- **Pfad:** `core.*` vs `modules.*`
- **Enable:** Core = immer aktiv, Modules = opt-in

## **Fazit**

**JA!** Das Schema sollte:
- ✅ **Minimale Requirements** definieren
- ✅ **Dokumentation** im Template integrieren
- ✅ **Assertions** für automatische Detection
- ✅ **Gleiche Struktur** für alle Module-Typen
- ✅ **Automatische Validation** bei Discovery
