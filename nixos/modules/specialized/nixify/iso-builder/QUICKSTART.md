# Quick Start: ISO bauen

## Einfachste Methode

```bash
cd nixos/modules/specialized/nixify/iso-builder
nix-build build-iso.nix
```

Die ISO findest du dann in:
```
result/iso/nixos-nixify-*.iso
```

## Was passiert?

1. **NixOS ISO Base** wird gebaut (mit Calamares)
2. **Dein Calamares-Modul** wird kompiliert
3. **NixOS Control Center Repository** wird auf ISO kopiert
4. **ISO wird erstellt**

## ISO testen

```bash
# In QEMU
qemu-system-x86_64 -cdrom result/iso/nixos-nixify-*.iso -m 4G

# Oder auf USB brennen
sudo dd if=result/iso/nixos-nixify-*.iso of=/dev/sdX bs=4M status=progress
```

## Troubleshooting

### "path is not allowed to reference store paths"
- Du musst `nix-build` verwenden, nicht `nix eval`
- Oder verwende `builtins.path` in der Konfiguration

### Calamares-Modul wird nicht angezeigt
- Prüfe `/etc/calamares/modules.conf` auf der ISO
- Stelle sicher, dass das Modul in `sequence` steht

### Repository nicht auf ISO
- Prüfe `isoImage.contents` in `iso-config.nix`
- Stelle sicher, dass der Pfad korrekt ist
