# Zentrale ModuleConfig mit dynamischen Namen - Phase 2: Core Implementation

## 🎯 Phase Overview

- **Status**: 🔄 In Progress
- **Estimated Time**: 45 min
- **Actual Time**: 0 min
- **Progress**: 0%

## 📋 Tasks To Complete

### 🔄 Aktualisiere module-manager/config.nix
- [ ] Ändere automaticModuleConfigs um dynamische Namen zu generieren
- [ ] Verwende `name = baseNameOf (toString module.path);` statt `name = module.name;`
- [ ] Stelle sicher dass moduleConfig korrekt generiert wird

### 🔄 Aktualisiere system-logging/config.nix
- [ ] Füge `moduleConfig` zu function parameters hinzu
- [ ] Ändere cfg auf `systemConfig.${moduleConfig.system-logging.configPath} or {};`
- [ ] Entferne direkte Pfad-Verwendung

### 🔄 Verifiziere ssh-client-manager Merging
- [ ] Schaue dir lokale moduleConfig Generierung an
- [ ] Verstehe wie _module.args merging funktioniert
- [ ] Dokumentiere als Best Practice

### 🔄 Teste zentrale dynamische Generierung
- [ ] Verifiziere dass module-manager dynamische Namen generiert
- [ ] Stelle sicher dass cfg resolution funktioniert
- [ ] Teste nixos-rebuild dry-run

## 🔧 Implementation Details

### Korrekte Lösung: Zentrale dynamische Generierung

**module-manager generiert moduleConfig zentral mit dynamischen Namen:**

```nix
# In module-manager/config.nix:
automaticModuleConfigs = lib.listToAttrs (
  map (module: {
    name = baseNameOf (toString module.path); # ✅ DYNAMISCH!
    value = {
      configPath = "systemConfig.${category}.${baseNameOf (toString module.path)}";
      enablePath = "${configPath}.enable";
      apiPath = "config.core.${category}.${baseNameOf (toString module.path)}";
      name = baseNameOf (toString module.path);
      category = module.category;
      path = module.path;
    };
  }) discoveredModules
);
```

### Warum diese Lösung besser ist:

1. **Zentralisiert** - Ein Ort für alle moduleConfig
2. **Dynamisch** - Namen aus filesystem
3. **Skalierbar** - Neue Module automatisch erkannt
4. **Merging** - Lokale Überschreibungen möglich

### module-manager/config.nix Änderungen:

**VOR (falsch - verwendet module.name):**
```nix
automaticModuleConfigs = lib.listToAttrs (
  map (module: {
    name = module.name; # ❌ Statisch aus discovery
    value = { ... };
  }) discoveredModules
);
```

**NACH (richtig - dynamisch aus filesystem):**
```nix
automaticModuleConfigs = lib.listToAttrs (
  map (module: {
    name = baseNameOf (toString module.path); # ✅ Dynamisch!
    value = { ... };
  }) discoveredModules
);
```

### system-logging/config.nix Änderungen:

**VOR:**
```nix
{ config, lib, pkgs, systemConfig, ... }: # ❌ moduleConfig fehlt
let
  cfg = systemConfig.core.management.system-manager.submodules.system-logging or {};
```

**NACH:**
```nix
{ config, lib, pkgs, systemConfig, moduleConfig, ... }: # ✅ moduleConfig hinzugefügt
let
  cfg = systemConfig.${moduleConfig.system-logging.configPath} or {};
```

## 🧪 Testing Strategy

### Unit Tests:
- [ ] Syntax check aller modifizierten Files
- [ ] Verifiziere dynamische Namen Generierung
- [ ] Test cfg resolution

### Integration Tests:
- [ ] nixos-rebuild dry-run
- [ ] Module loading verification
- [ ] moduleConfig structure validation

### Merging Tests:
- [ ] ssh-client-manager lokale Überschreibungen testen
- [ ] Globale + lokale configs kombinieren
- [ ] baseNameOf Konsistenz prüfen

## ⚠️ Critical Points

### baseNameOf im module-manager:
- `baseNameOf (toString module.path)` gibt den Ordnernamen
- Funktioniert für alle discovered modules
- Beispiel: `/path/to/system-update` → `system-update`

### Parameter hinzufügen:
- **system-logging**: `moduleConfig` Parameter hinzufügen

### Merging verstehen:
- module-manager setzt globale moduleConfig
- Einzelne Module können lokale hinzufügen
- `lib.mkMerge` kombiniert alles

## 🎯 Phase 2 Success Criteria

- [ ] module-manager generiert dynamische Namen
- [ ] system-logging verwendet moduleConfig
- [ ] Syntax checks passieren
- [ ] nixos-rebuild dry-run erfolgreich
- [ ] Dynamische Generierung funktioniert

## 🚀 Next Steps

Nach Phase 2 Completion:
- Phase 3: Integration & Testing
- Phase 4: Documentation & Finalization
