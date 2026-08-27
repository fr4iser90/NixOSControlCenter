# Validierung und Build-Script

Das Script `validate-and-build.sh` führt automatisch alle Validierungsschritte durch, baut die ISO und prüft den Output.

## Verwendung

```bash
cd nixos/modules/specialized/nixify/iso-builder
./validate-and-build.sh [desktop-env]
```

**Parameter:**
- `desktop-env`: Desktop-Umgebung (Standard: `plasma6`, Optionen: `plasma6`, `gnome`)

**Beispiele:**
```bash
# Plasma6 (Standard)
./validate-and-build.sh

# Plasma6 (explizit)
./validate-and-build.sh plasma6

# GNOME
./validate-and-build.sh gnome
```

## Was das Script macht

1. **Schritt 1:** Prüft, ob `iso-config.nix` existiert
2. **Schritt 2:** Validiert, dass `contents` die richtige Anzahl Einträge hat (>= 12)
3. **Schritt 3:** Prüft, ob die Custom-Derivationen in der ISO-Derivation referenziert sind
4. **Schritt 4:** Prüft, ob `baseIsoModule` `lib.mkForce` verwendet (würde die Liste überschreiben)
5. **Schritt 5:** Baut die ISO-Derivation (ohne vollständige ISO)
6. **Schritt 6:** Prüft, ob die Dateien in der ISO-Struktur vorhanden sind:
   - `etc/calamares/settings.conf`
   - `etc/calamares/modules.conf`
   - `usr/lib/calamares/modules/nixos-control-center`
   - `usr/lib/calamares/modules/nixos-control-center-job`
   - `nixos/flake.nix`
7. **Schritt 7:** Baut die vollständige ISO (mit `ncc` oder `nix-build`)
8. **Schritt 8:** Validiert die gebaute ISO-Datei
9. **Schritt 9:** Zeigt Zusammenfassung mit ISO-Pfad

## Output

Das Script gibt farbigen Output:
- ✓ Grün: Erfolgreich
- ✗ Rot: Fehler
- ℹ Gelb: Information

## Exit-Codes

- `0`: Alle Schritte erfolgreich
- `1`: Fehler bei Validierung oder Build

## Beispiel-Output

```
=== NixOS ISO Validierung und Build ===
Desktop Environment: plasma6

Schritt 1: Prüfe ISO-Config...
✓ ISO-Config gefunden

Schritt 2: Validiere contents-Liste...
ℹ contents hat 17 Einträge
✓ contents hat genügend Einträge

...

=== Validierung und Build abgeschlossen ===
✓ Alle Schritte erfolgreich!
ℹ ISO-Pfad: /home/user/.local/share/nixify/isos/nixos-nixify-plasma6-*.iso
```

## Fehlerbehebung

Wenn das Script fehlschlägt:
1. Prüfe die Fehlermeldungen
2. Stelle sicher, dass alle Abhängigkeiten installiert sind
3. Prüfe, ob `ncc` verfügbar ist (oder `nix-build`)
4. Prüfe die ISO-Config auf Syntaxfehler
