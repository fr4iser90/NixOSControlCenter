# Desktop-Modul: Implementierungsplan

## 🎯 Ziel

Desktop-Modul nach Template-Struktur migrieren mit:
- ✅ Template-konforme Struktur (flach, Level 1 für Verzeichnisse)
- ✅ User-Config in `user-configs/desktop-config.nix` (1 Ebene, kategorisiert)
- ✅ Symlink-Management für zentrale Bearbeitung
- ✅ Konsistent mit Migration-Plan

---

## 📊 Aktuelle Struktur-Analyse

### Verzeichnisstruktur (Level 2)
```
desktop/
├── audio/                # Level 1
│   ├── alsa.nix
│   ├── pipewire.nix
│   └── pulseaudio.nix
├── display-managers/     # Level 1
│   ├── gdm/              # Level 2
│   ├── lightdm/          # Level 2
│   └── sddm/             # Level 2
├── display-servers/      # Level 1
│   ├── wayland/          # Level 2
│   └── x11/              # Level 2
├── environments/         # Level 1
│   ├── gnome/            # Level 2
│   ├── plasma/           # Level 2
│   └── xfce/             # Level 2
├── themes/               # Level 1
│   ├── color-schemes/    # Level 2
│   ├── cursors/
│   ├── fonts/
│   └── icons/
└── default.nix
```

**Status**: ✅ **Bereits Template-konform!**
- Verzeichnisse sind flach (Level 1)
- Submodule (gdm/, plasma/, etc.) sind Implementierungsdetails
- Keine Änderung nötig

---

## 📝 Ziel-Struktur

### Verzeichnisstruktur (bleibt gleich)
```
desktop/
├── user-configs/         # NEU: User-editable Config
│   └── desktop-config.nix
├── default.nix           # ANPASSEN: Symlink-Management hinzufügen, audio/ import entfernen
├── options.nix           # NEU: Option-Definitionen (falls nötig)
├── display-managers/
├── display-servers/
├── environments/
└── themes/
```

### Config-Struktur (1 Ebene, kategorisiert)
```nix
# user-configs/desktop-config.nix
{
  desktop = {
    enable = false;
    
    # Display-Server
    display = {
      server = "wayland";  # wayland | x11 | hybrid
      manager = "sddm";    # sddm | gdm | lightdm
      session = "plasma";  # plasma | gnome | xfce
    };
    
    # Desktop-Environment
    environment = "plasma";  # plasma | gnome | xfce
    
    # Theme
    theme = {
      dark = true;
      # Weitere Theme-Optionen später
    };
    
    # Keyboard
    keyboard = {
      layout = "us";
      options = "";
    };
  };
}
```

**⚠️ WICHTIG: Audio ist NICHT mehr Teil von Desktop!**
- Audio wird eigenes Modul: `core/audio/`
- Desktop nutzt Audio-Modul (wenn enabled)
- Audio-Config: `core/audio/user-configs/audio-config.nix`

**Warum 1 Ebene?**
- Alle Kategorien auf gleicher Ebene (`display`, `environment`, `theme`, `keyboard`)
- Audio ist **NICHT** Teil von Desktop (eigenes Modul)
- Einfach zu verstehen und zu editieren
- Konsistent mit Template (Level 1)

---

## 🔄 Migrations-Schritte

### Schritt 1: Vorbereitung
- [ ] Backup bestehender `desktop-config.nix` (falls vorhanden)
- [ ] Dokumentiere aktuelle Config-Struktur
- [ ] Prüfe welche Optionen aktuell verwendet werden

### Schritt 2: Verzeichnisstruktur erstellen
```bash
mkdir -p nixos/core/desktop/user-configs
```

### Schritt 3: Default-Config erstellen
**Datei**: `nixos/core/desktop/user-configs/desktop-config.nix`

**Inhalt**:
```nix
{
  desktop = {
    enable = false;
    environment = "plasma";
    display = {
      manager = "sddm";
      server = "wayland";
      session = "plasma";
    };
    theme = {
      dark = true;
    };
    keyboard = {
      layout = "us";
      options = "";
    };
  };
}
```

### Schritt 4: Migration bestehender Config
**Wenn `/etc/nixos/configs/desktop-config.nix` existiert:**
- [ ] Kopiere Inhalt nach `core/desktop/user-configs/desktop-config.nix`
- [ ] Passe Struktur an (1 Ebene, kategorisiert)
- [ ] Validiere Syntax (`nix-instantiate --parse`)
- [ ] Test: Config wird korrekt geladen

### Schritt 5: Symlink-Management in default.nix
**Datei**: `nixos/core/desktop/default.nix`

**Änderungen**:
1. Symlink-Management hinzufügen (siehe MIGRATION_PLAN.md, Schritt 5)
2. Default-Config-Erstellung
3. Bestehender Code bleibt (imports, assertions, etc.)

**Wichtig**:
- Symlink wird in `system.activationScripts` erstellt
- Default-Config wird erstellt, falls nicht vorhanden
- Symlink zeigt auf `user-configs/desktop-config.nix`

### Schritt 6: flake.nix anpassen
**Datei**: `nixos/flake.nix`

**Änderung**: `loadConfig` erweitern (siehe MIGRATION_PLAN.md, Schritt 6)
- Lädt von `./core/desktop/user-configs/desktop-config.nix`
- Fallback: `./configs/desktop-config.nix` (Legacy)

### Schritt 7: Testen
- [ ] `nixos-rebuild switch --flake /etc/nixos#hostname`
- [ ] Prüfe: Symlink wurde erstellt
- [ ] Prüfe: Symlink zeigt auf richtige Datei
- [ ] Test: Desktop-Funktionalität (falls `desktop.enable = true`)
- [ ] Test: User kann Config in `/etc/nixos/configs/` editieren
- [ ] Test: Änderungen werden übernommen nach Rebuild

### Schritt 8: Dokumentation
- [ ] README.md aktualisieren
- [ ] Erkläre neue Struktur
- [ ] Erkläre wo User editieren soll (`/etc/nixos/configs/`)

---

## 📋 Checkliste

### Vorbereitung
- [ ] Backup bestehender Config
- [ ] Verzeichnisstruktur erstellt (`user-configs/`)
- [ ] Aktuelle Config-Struktur dokumentiert

### Implementierung
- [ ] `user-configs/desktop-config.nix` erstellt
- [ ] Default-Config definiert (1 Ebene, kategorisiert)
- [ ] Symlink-Management in `default.nix` implementiert
- [ ] Bestehende Config migriert (falls vorhanden)
- [ ] `flake.nix` `loadConfig` angepasst

### Testing
- [ ] Symlink wird erstellt
- [ ] Symlink zeigt auf richtige Datei
- [ ] Desktop-Funktionalität funktioniert
- [ ] User kann Config editieren
- [ ] Änderungen werden übernommen

### Dokumentation
- [ ] README aktualisiert
- [ ] Migration dokumentiert
- [ ] Config-Struktur erklärt

---

## 🎨 Config-Struktur-Details

### Kategorien (1 Ebene)

1. **`desktop.enable`** (bool)
   - Aktiviert/Deaktiviert Desktop-Modul

2. **`desktop.environment`** (enum: "plasma" | "gnome" | "xfce")
   - Desktop-Environment Auswahl

3. **`desktop.display`** (object)
   - `server`: "wayland" | "x11" | "hybrid"
   - `manager`: "sddm" | "gdm" | "lightdm"
   - `session`: "plasma" | "gnome" | "xfce"

4. **`desktop.theme`** (object)
   - `dark`: bool
   - Weitere Optionen später

6. **`desktop.keyboard`** (object)
   - `layout`: string (z.B. "us", "de")
   - `options`: string

**Audio:**
- Audio ist **NICHT** Teil von Desktop-Config
- Audio wird eigenes Modul: `core/audio/user-configs/audio-config.nix`
- Desktop nutzt Audio-Modul (wenn enabled)

**Warum diese Struktur?**
- ✅ 1 Ebene (kategorisiert)
- ✅ Klar und übersichtlich
- ✅ Einfach zu editieren
- ✅ Konsistent mit Template

---

## 🔍 Vergleich: Vorher vs. Nachher

### Vorher (zentral)
```
/etc/nixos/configs/desktop-config.nix  # User editiert hier
↓
flake.nix lädt Config
↓
desktop/default.nix verwendet systemConfig.desktop
```

### Nachher (modular)
```
/etc/nixos/configs/desktop-config.nix  # Symlink
↓
core/desktop/user-configs/desktop-config.nix  # Echte Datei
↓
flake.nix lädt echte Datei
↓
desktop/default.nix verwendet systemConfig.desktop
```

**Vorteile**:
- ✅ Config ist co-located mit Modul
- ✅ Versionierung mit Modul
- ✅ Migration einfacher
- ✅ User kann weiterhin zentral editieren (via Symlink)

---

## ⚠️ Wichtige Hinweise

1. **Template-Konformität**: ✅
   - Verzeichnisse sind bereits flach (Level 1)
   - Keine Änderung nötig

2. **Config-Struktur**: ✅
   - 1 Ebene, kategorisiert
   - Konsistent mit Template

3. **Symlink-Strategie**: ✅
   - User editiert in `/etc/nixos/configs/`
   - Änderungen landen in `user-configs/`
   - `flake.nix` lädt echte Datei

4. **Backward Compatibility**: ✅
   - Fallback auf Legacy-Config in `loadConfig`
   - Migration unterstützt alte Systeme

---

## 📚 Referenzen

- **Template**: `nixos/features/.TEMPLATE/README.md`
- **Migration-Plan**: `nixos/MIGRATION_PLAN.md` (Phase 2.1, Schritt 1-10)
- **Ebenen-Analyse**: `Overview_modules.md`

---

## ✅ Nächste Schritte

1. **Sofort**: Schritt 1-3 (Vorbereitung, Verzeichnis, Default-Config)
2. **Diese Woche**: Schritt 4-6 (Migration, Symlink, flake.nix)
3. **Nächste Woche**: Schritt 7-8 (Testing, Dokumentation)

**Danach**: 
- Audio-Modul erstellen (`core/audio/`)
- Weitere Module nach gleichem Muster migrieren

## 📝 Audio-Modul (später)

**Neues Modul**: `core/audio/`
- Config: `core/audio/user-configs/audio-config.nix`
- Struktur: `{ audio = { system = "pipewire"; ... }; }`
- Desktop nutzt Audio-Modul (wenn enabled)

