# Config-Dateien Format - Korrekte Struktur

## ❗ WICHTIG: VERMISChte Logik!

**Die *-config.nix Dateien bleiben SO WIE SIE SIND!**
Sie definieren direkt `audio = {...}`, `desktop = {...}`, etc.

**Das Problem ist die system-config.nix!**
Sie muss die `system.*` Struktur haben, damit die Module `systemConfig.system.audio` finden.

## 🎯 RICHTIGE AUFTEILUNG:

### system-config.nix (die HAUPT-Konfiguration)
```nix
{
  # System Identity (bleibt)
  systemType = "desktop";
  hostName = "Gaming";
  bootloader = "systemd-boot";
  system = { channel = "stable"; };
  allowUnfree = true;
  users = { "fr4iser" = { role = "admin"; defaultShell = "zsh"; autoLogin = true; }; };
  timeZone = "Europe/Berlin";

  # NEU: System-Module Konfiguration!
  system = {
    audio = { enable = true; system = "pipewire"; };
    desktop = { enable = true; environment = "plasma"; /* ... */ };
    localization = { enable = true; locales = ["de_DE.UTF-8"]; /* ... */ };
    hardware = { enable = true; cpu = "intel"; /* ... */ };
    network = { enable = true; /* ... */ };
    packages = { enable = true; preset = null; };
  };
}
```

### *-config.nix Dateien (bleiben unverändert!)
```nix
# audio-config.nix (BLEIBT SO!)
{
  audio = {
    enable = true;
    system = "pipewire";
  };
}

# desktop-config.nix (BLEIBT SO!)
{
  desktop = {
    enable = true;
    environment = "plasma";
    # ...
  };
}
```

## 🔄 Wie das merging funktioniert:
1. CONFIG-LOADER lädt `system-config.nix` → hat `system.audio`
2. CONFIG-LOADER lädt `audio-config.nix` → überschreibt/mergt `audio`
3. Modul findet `systemConfig.system.audio` ✅

## 🛠️ Was zu tun ist:
**Nur system-config.nix korrigieren!**
Die *-config.nix Dateien sind bereits richtig!

## ✅ Management/Features bleiben UNVERÄNDERT:

### management-config.nix (bleibt so)
```nix
{
  management = {
    checks = {
      enable = true;
      postbuild = { enable = true; checks = { passwords.enable = true; filesystem.enable = true; services.enable = true; }; };
      prebuild = { enable = true; checks = { cpu.enable = true; gpu.enable = true; memory.enable = true; users.enable = true; }; };
    };
  };
}
```

### cli-formatter-config.nix (bleibt so)
```nix
{
  core = {
    cli-formatter = {
      enable = true;
      config = {};
      components = {};
    };
  };
}
```

### command-center-config.nix (bleibt so)
```nix
{
  command-center = {
    enable = true;
  };
}
```

### logging-config.nix (bleibt so)
```nix
{
  core = {
    management = {
      logging = {
        enable = true;
        defaultDetailLevel = "info";
        collectors = { ... };
      };
    };
  };
}
```

### system-manager-config.nix ❌ NICHT NÖTIG!
```nix
# System-Manager ist immer aktiv - keine Config nötig
# Diese Datei kann entfernt werden oder leer bleiben
{}
```

### system-update-config.nix (bleibt so)
```nix
{
  systemConfig.core.management.system-manager.submodules.system-update = {
    enable = true;
    autoBuild = false;
    backup = {
      enable = true;
      retention = 5;
      directory = "/var/backup/nixos";
    };
    sources = [
      {
        name = "remote";
        url = "https://github.com/fr4iser90/NixOSControlCenter.git";
        branches = ["main" "develop" "experimental"];
      }
      {
        name = "local";
        url = "/home/user/Documents/Git/NixOSControlCenter/nixos";
        branches = [];
      }
    ];
  };
}
```

## 🚨 WICHTIG:
- **System-Module**: `system.*` (audio, desktop, hardware, etc.)
- **Management-Module**: Direkt auf Root-Ebene (management, core, command-center)
- **Features**: Direkt auf Root-Ebene (features, overrides, etc.)
- **Unnötige Module**: boot-config.nix, user-config.nix, system-manager-config.nix können entfernt werden

## 🛠️ Automatische Korrektur:
```bash
# Erstelle Backups
for file in /etc/nixos/configs/*-config.nix; do
  cp "$file" "${file}.backup"
done

# Entferne unnötige Dateien
rm -f /etc/nixos/configs/boot-config.nix
rm -f /etc/nixos/configs/user-config.nix
rm -f /etc/nixos/configs/system-manager-config.nix
