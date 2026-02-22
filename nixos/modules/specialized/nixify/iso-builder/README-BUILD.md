# NixOS ISO Builder mit Calamares Integration

Dieser ISO-Builder erstellt eine Custom NixOS ISO mit:
- **Calamares** grafischer Installer
- **NixOS Control Center** Custom-Modul integriert
- **Komplettes Repository** auf der ISO

## Voraussetzungen

Du musst **KEINE** ISO runterladen! Wir bauen die ISO direkt mit Nix.

### Benötigt:
- NixOS oder Nix installiert
- Genug Speicherplatz (~5-10GB für Build)
- Internet-Verbindung (für Downloads)

## Build-Prozess

### Option 1: Direkt mit nix-build (Einfachste Methode)

```bash
cd nixos/modules/specialized/nixify/iso-builder
nix-build build-iso.nix
```

Die ISO wird in `result/iso/` erstellt.

### Option 2: Mit Flake (Empfohlen für Entwicklung)

Erstelle eine `flake.nix` im ISO-Builder-Verzeichnis:

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  
  outputs = { self, nixpkgs }: {
    iso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./iso-config.nix
      ];
    };
  };
}
```

Dann:
```bash
nix build .#iso
```

### Option 3: In deine bestehende Flake integrieren

Füge zu deiner `flake.nix` hinzu:

```nix
{
  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations = {
      # ... deine bestehenden Configs ...
    };
    
    # ISO Output
    iso = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nixos/modules/specialized/nixify/iso-builder/iso-config.nix
      ];
    };
  };
}
```

Dann:
```bash
nix build .#iso.config.system.build.isoImage
```

## Was passiert beim Build?

1. **NixOS ISO Base** wird erstellt (mit Calamares)
2. **Calamares-Modul** wird kompiliert und integriert
3. **NixOS Control Center Repository** wird auf die ISO kopiert
4. **ISO wird gebaut** mit allen Komponenten

## ISO-Struktur

Nach dem Build:
```
result/iso/
├── nixos-nixify-*.iso          # Die fertige ISO
└── iso/                        # ISO-Inhalt
    ├── nixos/                  # Dein Repository
    │   ├── shell/
    │   ├── nixos/
    │   └── ...
    └── [Calamares Files]
```

## Installation

1. **ISO auf USB/DVD brennen**
2. **Booten** vom USB/DVD
3. **Calamares startet** automatisch
4. **Dein Custom-Modul** erscheint nach Partitionierung
5. **Konfiguration wählen** (Presets/Custom/Advanced)
6. **Installation starten**

## Troubleshooting

### Build schlägt fehl wegen fehlender Module
```bash
# Stelle sicher, dass nixpkgs aktuell ist
nix-channel --update
```

### Calamares-Modul wird nicht angezeigt
- Prüfe `services.calamares.settings.sequence` in `iso-config.nix`
- Stelle sicher, dass das Modul in `show` und `exec` steht

### Repository nicht auf ISO
- Prüfe `isoImage.contents` in `iso-config.nix`
- Stelle sicher, dass der Pfad korrekt ist

## Nächste Schritte

Nach erfolgreichem Build:
1. **ISO testen** in VM (QEMU/VirtualBox)
2. **Calamares-Modul testen** - alle Pages durchgehen
3. **Installation testen** - komplette Installation durchführen
4. **Anpassungen** - je nach Test-Ergebnissen

## Alternative: Ohne Calamares (Terminal-basiert)

Falls du doch lieber Terminal-basiert installieren willst:

```bash
# Verwende installation-cd-minimal.nix statt installation-cd-graphical-calamares-gnome.nix
# Dann läuft dein Shell-Installer direkt
```
