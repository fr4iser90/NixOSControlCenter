# Auto-Discovery Plan: Features automatisch erkennen

## 🎯 Ziel

**Wenn du ein neues Feature hinzufügst:**
1. Feature-Ordner erstellen: `features/my-new-feature/`
2. `options.nix` mit `featureVersion` erstellen
3. **FERTIG!** Alles andere wird automatisch erkannt!

## 📋 Lösung

### 1. Auto-Discovery: Features automatisch aus Verzeichnis lesen

**Statt manuell in `featureModuleMap` eintragen:**
```nix
# ALT: Manuell
featureModuleMap = {
  "system-discovery" = ./system-discovery;
  "ssh-client-manager" = ./ssh-client-manager;
  # ... muss überall eintragen!
};
```

**NEU: Automatisch:**
```nix
# Automatisch alle Features aus features/ Verzeichnis lesen
featureModuleMap = lib.mapAttrs' (name: _: {
  name = name;
  value = ./${name};
}) (builtins.readDir ./features);
```

### 2. Auto-Metadata: `latestVersion` automatisch aus `options.nix` lesen

**Statt manuell in `metadata.nix` eintragen:**
```nix
# ALT: Manuell
"system-discovery" = {
  latestVersion = "1.0";  # Muss manuell eintragen!
  dependencies = [];
  conflicts = [];
};
```

**NEU: Automatisch:**
```nix
# Liest latestVersion automatisch aus features/*/options.nix
getLatestVersion = featureName:
  let
    optionsFile = ./${featureName}/options.nix;
    # Parse options.nix und extrahiere featureVersion
  in ...;
```

### 3. Auto-Registration: Features automatisch aktivieren

**Statt manuell in `activeFeatures` eintragen:**
```nix
# ALT: Manuell
activeFeatures = {
  "system-discovery" = cfg.system-discovery or false;
  "ssh-client-manager" = cfg.ssh-client-manager or false;
  # ... muss überall eintragen!
};
```

**NEU: Automatisch:**
```nix
# Automatisch aus systemConfig.features lesen
activeFeatures = lib.filterAttrs (name: enabled: enabled) 
  (systemConfig.features or {});
```

## 🚀 Implementierung

### Schritt 1: Auto-Discovery in `features/default.nix`

```nix
# Automatisch alle Features aus Verzeichnis lesen
allFeatureDirs = builtins.readDir ./.;
featureModuleMap = lib.mapAttrs' (name: type:
  lib.nameValuePair name (./. + "/${name}")
) (lib.filterAttrs (name: type: 
  type == "directory" && name != ".TEMPLATE"
) allFeatureDirs);
```

### Schritt 2: Auto-Metadata Generator

```nix
# Generiert metadata.nix automatisch aus Features
generateMetadata = lib.mapAttrs (name: path:
  let
    options = import (path + "/options.nix") { inherit lib; };
    # Extrahiere featureVersion aus options
    version = options.featureVersion or "1.0";
  in {
    latestVersion = version;
    dependencies = [];  # Kann später aus options.nix gelesen werden
    conflicts = [];      # Kann später aus options.nix gelesen werden
  }
) featureModuleMap;
```

### Schritt 3: Auto-Registration

```nix
# Automatisch aus systemConfig.features lesen
activeFeatures = lib.filterAttrs (name: enabled: enabled)
  (systemConfig.features or {});
```

## ✅ Ergebnis

**Wenn du ein neues Feature hinzufügst:**

1. ✅ Feature-Ordner: `features/my-new-feature/`
2. ✅ `options.nix` mit `featureVersion = "1.0"`
3. ✅ **FERTIG!** Alles wird automatisch erkannt!

**Keine manuellen Einträge mehr in:**
- ❌ `features/default.nix` → `featureModuleMap`
- ❌ `features/default.nix` → `activeFeatures`
- ❌ `features/metadata.nix` → `latestVersion`

**Alles automatisch!**

