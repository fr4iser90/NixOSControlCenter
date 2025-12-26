[3 tools called]

## **📁 Reine cli-formatter Component Struktur**

**VON (aktuell - Modul-artig):**
```
components/cli-formatter/
├── default.nix        ❌ (Modul Entry Point)
├── options.nix        ❌ (Modul Options)
├── api.nix           ❌ (Öffentliche API)
├── config.nix        ✅ (Implementation)
├── colors.nix        ✅ (Utility)
├── components/       ✅ (Sub-Components)
├── core/            ✅ (Core Logic)
├── interactive/     ✅ (Interactive Features)
└── status/          ✅ (Status Features)
```

**NACH (rein - nur Implementation):**
```
components/cli-formatter/
├── lib/              ← NEU: Reine Utilities
│   ├── colors.nix    ← Aus root verschoben
│   └── utils.nix     ← Neue Helper Functions
├── handlers/         ← NEU: Business Logic
│   ├── format-handler.nix   ← Aus config.nix
│   └── theme-handler.nix    ← Neue Theme-Logik
├── templates/        ← NEU: UI Templates
│   ├── text-templates.nix   ← Aus core/
│   ├── list-templates.nix   ← Aus components/
│   └── status-templates.nix ← Aus status/
└── interactive/      ← BLEIBT: TUI Features
    ├── fzf.nix
    ├── menus.nix
    ├── prompts.nix
    └── tui/
        ├── components/
        └── main.nix
```

---

## **📄 Konkrete Datei-Beispiele**

### **components/cli-formatter/handlers/format-handler.nix**
```nix
# REINE Component - KEINE Modul-Struktur!
{ config, lib, pkgs, systemConfig, ... }:

let
  # Component bekommt Config vom Hauptmodul
  cfg = config;  # nixos-control-center.format
  
  # Interne Component-Utilities
  colors = import ../lib/colors.nix;
  textTemplates = import ../templates/text-templates.nix { inherit colors; };

in {
  # KEINE _module.metadata!
  # KEINE options-Definitionen!
  
  # Reine Implementation
  config = lib.mkIf cfg.enable {
    # Component-spezifische Config
    environment.systemPackages = [ pkgs.gum ];  # Für TUI
    
    # Component-API für Hauptmodul
    # (wird vom Hauptmodul verwendet)
    nixos-control-center.format = {
      text = textTemplates;
      colors = colors;
      tables = import ../templates/list-templates.nix { inherit colors; };
    };
  };
}
```

### **components/cli-formatter/lib/colors.nix**
```nix
# Reine Utility - keine Modul-Logik
{
  # Color definitions
  red = "\\033[31m";
  green = "\\033[32m";
  blue = "\\033[34m";
  reset = "\\033[0m";
  
  # Helper functions
  colorize = color: text: "${color}${text}${reset}";
  success = text: colorize green "✓ ${text}";
  error = text: colorize red "✗ ${text}";
}
```

### **components/cli-formatter/templates/text-templates.nix**
```nix
# Reine Templates - wiederverwendbare UI-Components
{ colors }:

{
  # Text formatting templates
  header = text: ''
    ${colors.blue}========================================${colors.reset}
    ${colors.bold}${text}${colors.reset}
    ${colors.blue}========================================${colors.reset}
  '';
  
  subHeader = text: "${colors.cyan}${text}${colors.reset}";
  normal = text: text;
  bold = text: "${colors.bold}${text}${colors.reset}";
}
```

---

## **🔗 Integration ins Hauptmodul**

### **nixos-control-center/default.nix**
```nix
imports = [
  ./options.nix
  ./config.nix
  # Components als reine Handler importieren
  ./components/cli-formatter/handlers/format-handler.nix
  ./components/cli-registry/handlers/registry-handler.nix
];
```

### **nixos-control-center/options.nix**
```nix
# Hauptmodul definiert Component-Options
options.systemConfig.core.management.nixos-control-center = {
  # Component-Features als Hauptmodul-Options
  format = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable CLI formatting component";
    };
    theme = mkOption {
      type = types.enum ["dark" "light" "auto"];
      default = "auto";
      description = "CLI formatter theme";
    };
  };
  
  registry = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable CLI registry component";
    };
  };
};
```

### **nixos-control-center/api.nix**
```nix
# Hauptmodul exportiert Component-Funktionalität
{ lib, ... }:

let
  # Components sind rein privat - nur Implementation
  formatterLib = import ./components/cli-formatter/lib/colors.nix;
  formatterTemplates = import ./components/cli-formatter/templates/text-templates.nix {
    colors = formatterLib;
  };

in {
  # ÖFFENTLICHE API des Hauptmoduls
  # Verwendet interne Components
  format = {
    text = formatterTemplates;
    colors = formatterLib;
  };
  
  # Registry API
  commands = {
    register = { ... };
    list = { ... };
  };
}
```

---

## **✅ Vorteile der reinen Component-Struktur**

### **Klare Trennung:**
- **Module** = Öffentliche APIs, Konfiguration, Integration
- **Components** = Reine Implementation, wiederverwendbare Bausteine

### **Einfachere Maintenance:**
- Components können unabhängig entwickelt werden
- Keine Modul-Overhead in Components
- Klare Verantwortlichkeiten

### **Automatische Detection:**
- Components werden NICHT als Module erkannt
- Nur echte Module zählen als solche
- Eliminiert die 241+ falschen Detections

### **Wiederverwendbarkeit:**
- Components können in anderen Modulen verwendet werden
- Klare Interfaces
- Testbare Einheiten

---

## **🔄 Migrations-Schritte für cli-formatter**

### **Schritt 1: Modul-Dateien entfernen**
```bash
rm components/cli-formatter/default.nix      # ❌
rm components/cli-formatter/options.nix      # ❌
rm components/cli-formatter/api.nix          # ❌ (wird ins Hauptmodul)
```

### **Schritt 2: Neue Struktur erstellen**
```bash
mkdir -p components/cli-formatter/{lib,handlers,templates}
mv components/cli-formatter/colors.nix components/cli-formatter/lib/
mv components/cli-formatter/config.nix components/cli-formatter/handlers/format-handler.nix
# ... weitere Umstrukturierungen
```

### **Schritt 3: Hauptmodul anpassen**
```nix
# Options für Component hinzufügen
# Handler importieren
# API definieren
```

---

## **🎯 Das Ergebnis**

**VOR:** 241+ "Module" (Components werden als Module erkannt)

**NACH:** ~15 echte Module + reine Components (nicht als Module gezählt)

**Das gibt dir die saubere, wartbare Architektur!** 🚀

**Willst du diese Struktur für cli-formatter implementieren?** Ich kann dir die konkreten Dateien zeigen.