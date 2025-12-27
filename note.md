# 🎯 KORREKTER PLAN: TUI-ENGINE ALS GENERISCHER BUILDER

**GENERISCHER TUI-BUILDER - JEDES MODUL MACHT SEIN EIGENES TUI!**

## **📁 RICHTIGE STRUKTUR** (basierend auf MODULE_TEMPLATE.md)

```
nixos/core/management/tui-engine/
├── api.nix                    # 🎯 API wie cli-formatter (direkt im Modul!)
├── components/
│   └── tui-engine/
│       └── default.nix        # Go Build-Logik
├── options.nix               # User options
├── config.nix                # API setup
└── default.nix               # Module entry
```

**KEINE spezifischen TUIs in der API** - jedes Modul definiert sein eigenes Go-Code! 🚨

## **🎯 IMPLEMENTIERUNG - ALLE DATEIEN:**

### **1. nixos/core/management/tui-engine/api.nix:**
```nix
# TUI Engine API - Generischer Builder für alle Module
{ lib }:

let
  # Import generische Build-Funktionen
  builders = import ./components/tui-engine/default.nix { inherit lib; };

in {
  # Export generische buildTUI Funktion für alle Module
  inherit (builders) buildTUI;
}
```

### **2. nixos/core/management/tui-engine/components/tui-engine/default.nix:**
```nix
{ lib }:
let
  buildTUI = { name, goCode, discoveryScript, pkgs }:
    pkgs.runCommand "${name}-tui" { buildInputs = [ pkgs.go ]; } ''
      mkdir -p $out/bin
      export GOPATH=$TMPDIR/go
      export GOCACHE=$TMPDIR/go-cache
      mkdir -p $GOPATH $GOCACHE

      cat > temp.go << 'EOF'
      ${goCode}
      EOF

      go build -o $out/bin/${name}-tui temp.go
    '';
in {
  # GENERISCHE TUI Build-Funktion für alle Module
  inherit buildTUI;
}
```
### **3. nixos/core/management/tui-engine/options.nix:**
```nix
{ lib, getCurrentModuleMetadata, ... }:
let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    enable = lib.mkEnableOption "TUI engine";
  };
}
```

### **4. nixos/core/management/tui-engine/config.nix:**
```nix
{ config, lib, getCurrentModuleMetadata, ... }:
let
  components = import ./components/tui-engine { inherit lib; };
  apiValue = {
    inherit (components) buildTUI;
  };
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  config.${configPath}.api = apiValue;
}
```

### **5. nixos/core/management/tui-engine/default.nix:**
```nix
{ config, lib, ... }:
{
  _module.metadata = {
    role = "core";
    name = "tui-engine";
    description = "Bubble Tea TUI engine";
    category = "management";
    subcategory = "Terminal";
    stability = "stable";
    version = "1.0.0";
  };
  _module.args.moduleName = "tui-engine";

  imports = [
    ./options.nix
    ./config.nix
  ];
}
```

### **6. nixos/core/management/default.nix:**
```nix
{
  imports = [
    ./system-manager
    ./module-manager
    ./nixos-control-center
    ./cli-registry
    ./cli-formatter
    ./tui-engine      # ← NEU HINZUFÜGEN
  ];
}
```


## **🎯 RESULTAT:**
```nix
# Jedes Modul macht sein eigenes TUI mit der generischen buildTUI Funktion:
let
  tuiEngine = getModuleApi "tui-engine";
in
tuiEngine.buildTUI {
  name = "mein-modul";        # Modul-definiert
  goCode = meinGoCode;        # Modul-definiert (Bubble Tea Code)
  discoveryScript = script;   # Modul-definiert
  inherit pkgs;
}
```

**KEINE spezifischen Builder in der API!** Jedes Modul ist verantwortlich für sein eigenes Go-Code! ✅
