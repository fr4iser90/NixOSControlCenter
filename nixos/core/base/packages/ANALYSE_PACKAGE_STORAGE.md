# Analyse: Package Storage - Systemweit vs. User-spezifisch

**Datum:** $(date)  
**Zweck:** Analyse der aktuellen Package-Speicherung und Identifikation von Verbesserungspotenzial

---

## 📊 Zusammenfassung

**Aktueller Status:** 
- ✅ **SystemPackages/UserPackages API existiert bereits** (V2 Format)
- ❌ **packageModules (V1 Legacy) installiert ALLES systemweit**
- ⚠️ **Keine Möglichkeit, packageModules in system/user zu unterteilen**

---

## 🔍 Detaillierte Analyse

### 1. Aktuelle Package-Speicherung

#### A) Systemweit installierte Packages

**Alle Packages werden aktuell über `environment.systemPackages` installiert:**

1. **Base Packages** (systemType-abhängig):
   - `components/base/desktop.nix` → `environment.systemPackages`
   - `components/base/server.nix` → `environment.systemPackages`

2. **Package Module Sets** (via `packageModules`):
   - Alle 15 Module-Sets in `components/sets/*.nix` verwenden `environment.systemPackages`:
     - `docker.nix`
     - `docker-rootless.nix`
     - `gaming.nix`
     - `web-dev.nix`
     - `python-dev.nix`
     - `streaming.nix`
     - `virt-manager.nix`
     - `qemu-vm.nix`
     - `emulation.nix`
     - `game-dev.nix`
     - `system-dev.nix`
     - `database.nix`
     - `web-server.nix`
     - `mail-server.nix`
     - `podman.nix`

3. **Direkte systemPackages Option** (V2 Format):
   - Wird korrekt über `environment.systemPackages` installiert
   - ✅ **Funktioniert bereits**

#### B) User-spezifische Packages

**Nur über `userPackages` Option (V2 Format):**
- Wird über `home-manager.users.<username>.home.packages` installiert
- ✅ **Funktioniert bereits**
- ⚠️ **Wird aber aktuell nicht genutzt** (keine Configs gefunden, die es verwenden)

---

## 📁 Code-Stellen

### 1. Package Module Verarbeitung

**Datei:** `nixos/core/base/packages/default.nix`

```19:37:nixos/core/base/packages/default.nix
  # Load package modules (V1 format)
  allModules = cfg.packageModules or [];

  # Determine actual Docker mode - enabled if "docker" or "docker-rootless" in packageModules
  dockerMode = let
    hasDocker = builtins.elem "docker" allModules;
    hasDockerRootless = builtins.elem "docker-rootless" allModules;
  in
    if hasDocker then "root"
    else if hasDockerRootless then "rootless"
    else null;

  # Smart Docker handling
  dockerModules = if dockerMode == "root" then [ ./components/sets/docker.nix ]
               else if dockerMode == "rootless" then [ ./components/sets/docker-rootless.nix ]
               else [];

  # Load feature modules
  moduleModules = map (mod: ./components/sets/${mod}.nix) allModules;
```

**Problem:** Alle `moduleModules` werden direkt importiert und installieren alles systemweit.

### 2. System Packages Installation

**Datei:** `nixos/core/base/packages/default.nix`

```59:69:nixos/core/base/packages/default.nix
  # System packages from systemPackages option
  environment.systemPackages = lib.mkIf ((cfg.systemPackages or []) != []) (
    map (pkgName:
      let
        meta = packageMetadata.modules.${pkgName} or {};
      in
        if meta ? package then meta.package
        else if builtins.hasAttr pkgName pkgs then pkgs.${pkgName}
        else throw "Package '${pkgName}' not found in package metadata or nixpkgs"
    ) cfg.systemPackages
  );
```

**Status:** ✅ Funktioniert korrekt für V2 Format

### 3. User Packages Installation

**Datei:** `nixos/core/base/packages/default.nix`

```71:85:nixos/core/base/packages/default.nix
  # Home-manager integration for userPackages (only if home-manager is available)
  home-manager = lib.mkIf (cfg.userPackages or {} != {}) {
    users = lib.mapAttrs (userName: packages:
      { config, ... }: {
        home.packages = map (pkgName:
          let
            meta = packageMetadata.modules.${pkgName} or {};
          in
            if meta ? package then meta.package
            else if builtins.hasAttr pkgName pkgs then pkgs.${pkgName}
            else throw "Package '${pkgName}' not found in package metadata or nixpkgs"
        ) packages;
      }
    ) cfg.userPackages;
  };
```

**Status:** ✅ Funktioniert korrekt, aber wird nicht genutzt

---

## 🎯 Identifizierte Probleme

### Problem 1: packageModules installiert alles systemweit

**Aktuelles Verhalten:**
- `packageModules = ["gaming", "web-dev"]` installiert ALLE Packages aus diesen Modulen systemweit
- Keine Möglichkeit, einzelne Packages aus einem Modul user-spezifisch zu installieren

**Beispiel:**
```nix
# Aktuell: ALLES systemweit
packages = {
  packageModules = ["gaming"];  # → vesktop, heroic, lutris, mangohud, goverlay → ALLE systemweit
};
```

**Gewünscht:**
```nix
# Ideale Lösung
packages = {
  packageModules = {
    gaming = {
      system = ["mangohud", "goverlay"];  # Systemweit
      user = {
        fr4iser = ["vesktop", "heroic", "lutris"];  # User-spezifisch
      };
    };
  };
};
```

### Problem 2: Keine Granularität in Package Modules

**Aktuell:**
- Package Module Sets sind "Alles-oder-Nichts"
- Keine Möglichkeit, einzelne Packages aus einem Set auszuwählen

**Beispiel `gaming.nix`:**
```17:31:nixos/core/base/packages/components/sets/gaming.nix
  # Gaming Launcher und Tools
  environment.systemPackages = with pkgs; [
    # Kommunikation
    vesktop              # Discord Client (privacy-freundlich)
    
    # Gaming Launcher
    heroic              # Epic Games & GOG Launcher (universell)
    lutris              # Gaming Launcher (unterstützt viele Stores)
    # legendary          # Epic Games CLI (optional, falls CLI bevorzugt wird)
    
    # Gaming Tools
    mangohud            # Performance Overlay für Games
    goverlay            # GUI für MangoHUD und andere Overlays
    # wine               # Wird normalerweise von Lutris/Steam mitgebracht
    # winetricks         # Wine Utilities
  ];
```

**Problem:** Alle Packages werden immer zusammen installiert, systemweit.

### Problem 3: Setup-Scripts verwenden nur Legacy Format

**Gefundene Scripts:**
- `shell/scripts/setup/modes/desktop/setup.sh` → verwendet nur `packageModules`
- `shell/scripts/setup/modes/custom/setup.sh` → verwendet nur `packageModules`
- `shell/scripts/setup/modes/server/setup.sh` → verwendet nur `packageModules`
- `shell/scripts/setup/config/data-collection/collect-system-data.sh` → verwendet nur `packageModules`

**Status:** ❌ Keine Unterstützung für `systemPackages`/`userPackages` in Setup-Scripts

---

## 📋 Statistiken

### Package Module Sets (alle systemweit)
- **Anzahl:** 15 Module-Sets
- **Alle verwenden:** `environment.systemPackages`
- **Keine verwenden:** `home.packages` oder user-spezifische Installation

### V2 API Nutzung
- **systemPackages:** ✅ Implementiert, aber nicht genutzt
- **userPackages:** ✅ Implementiert, aber nicht genutzt
- **packageModules:** ✅ Implementiert und aktiv genutzt (Legacy)

### Setup-Scripts
- **Anzahl Scripts mit packageModules:** 4+
- **Anzahl Scripts mit systemPackages/userPackages:** 0

---

## 🔧 Verbesserungsvorschläge

### Option 1: Package Module Sets erweitern (Empfohlen)

**Ansatz:** Package Module Sets in system/user Packages aufteilen

**Vorteile:**
- Backward-kompatibel (Legacy-Verhalten bleibt möglich)
- Granulare Kontrolle pro Package
- Nutzt bestehende V2 API

**Implementierung:**
1. Package Module Sets umstrukturieren:
   ```nix
   # Statt:
   environment.systemPackages = [...];
   
   # Neu:
   packages = {
     system = [...];
     user = {...};
   };
   ```

2. `default.nix` erweitern, um beide zu verarbeiten

### Option 2: Metadata-basierte Zuordnung

**Ansatz:** Package-Metadata erweitern mit `scope` (system/user)

**Vorteile:**
- Automatische Zuordnung basierend auf Package-Typ
- Weniger manuelle Konfiguration nötig

**Nachteile:**
- Weniger Flexibilität
- Packages müssen kategorisiert werden

### Option 3: Hybrid-Ansatz (Beste Lösung)

**Ansatz:** Kombination aus Option 1 + 2

1. Package Module Sets können system/user Packages definieren
2. Default-Verhalten: Alles systemweit (Backward-Kompatibilität)
3. Optional: Metadata-basierte Defaults für neue Packages
4. Setup-Scripts erweitern für V2 API

---

## 🎯 Empfohlene nächste Schritte

1. **Phase 1: Analyse abschließen** ✅ (Dieses Dokument)
2. **Phase 2: Package Module Sets umstrukturieren**
   - Neue Struktur für Sets definieren
   - Migration von bestehenden Sets
3. **Phase 3: default.nix erweitern**
   - Verarbeitung von system/user Packages aus Sets
   - Backward-Kompatibilität sicherstellen
4. **Phase 4: Setup-Scripts aktualisieren**
   - V2 API Unterstützung hinzufügen
   - Legacy-Support beibehalten
5. **Phase 5: Dokumentation aktualisieren**
   - Migration Guide
   - Best Practices

---

## 📝 Beispiel-Konfigurationen

### Aktuell (Legacy - Alles systemweit)
```nix
{
  packages = {
    packageModules = ["gaming", "web-dev"];
  };
}
```

### V2 Format (System + User)
```nix
{
  packages = {
    systemPackages = ["mangohud", "goverlay", "nginx"];
    userPackages = {
      fr4iser = ["vesktop", "vscode", "discord"];
      alice = ["firefox", "slack"];
    };
  };
}
```

### Ideal (Hybrid - Module Sets mit Granularität)
```nix
{
  packages = {
    packageModules = {
      gaming = {
        system = ["mangohud", "goverlay"];
        user = {
          fr4iser = ["vesktop", "heroic", "lutris"];
        };
      };
      "web-dev" = {
        system = ["nginx", "postgresql"];
        user = {
          fr4iser = ["vscode", "nodejs"];
        };
      };
    };
  };
}
```

---

## ✅ Fazit

**Aktueller Zustand:**
- ✅ V2 API (systemPackages/userPackages) ist implementiert
- ❌ Wird aber nicht genutzt
- ❌ packageModules installiert alles systemweit
- ❌ Keine Granularität in Package Module Sets

**Hauptproblem:**
Package Module Sets sind "Alles-oder-Nichts" und installieren immer systemweit. Es gibt keine Möglichkeit, einzelne Packages aus einem Set user-spezifisch zu installieren.

**Lösungsansatz:**
Package Module Sets umstrukturieren, um system/user Packages zu unterstützen, während Backward-Kompatibilität erhalten bleibt.
