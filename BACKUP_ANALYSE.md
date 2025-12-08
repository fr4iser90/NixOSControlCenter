# 🔍 VOLLSTÄNDIGE BACKUP-ANALYSE

## 📋 ÜBERSICHT: Wer macht Backups und wo?

### ❌ PROBLEM: Backups werden direkt in `/etc/nixos/` erstellt
Das führt zu:
- Unübersichtlichem Verzeichnis
- Vielen Backup-Dateien im Hauptverzeichnis
- Keiner zentralen Verwaltung
- Keiner automatischen Bereinigung

---

## 📍 ALLE BACKUP-STELLEN IM CODEBASE

### 1. **Config Migration** (`nixos/core/config/config-migration.nix`)
**Was:** Backups von `system-config.nix` vor Migrationen  
**Aktuell:**
- Zeile 149: `$SYSTEM_CONFIG.backup.YYYYMMDD_HHMMSS` → `/etc/nixos/system-config.nix.backup.*`
- Zeile 372: `$SYSTEM_CONFIG.backup.YYYYMMDD_HHMMSS` → `/etc/nixos/system-config.nix.backup.*`

**Problem:** Backups direkt neben der Datei

---

### 2. **Config Helpers** (`nixos/core/system-manager/lib/config-helpers.nix`)
**Was:** Backups von Config-Dateien beim Symlink-Update  
**Aktuell:**
- Zeile 48: `${symlinkPath}.backup.$(date +%s)` → z.B. `/etc/nixos/configs/desktop-config.nix.backup.*`

**Problem:** Backups direkt neben der Datei

---

### 3. **Utils.sh** (`shell/scripts/lib/utils.sh`)
**Was:** Generische Backup-Funktion `backup_file()`  
**Aktuell:**
- Zeile 60: `${file}.backup.YYYYMMDD_HHMMSS` → direkt neben der Datei

**Problem:** Wird von vielen Scripts verwendet, erstellt Backups überall

**Verwendet von:**
- `collect-system-data.sh` (Zeile 19)
- `setup/modes/server/setup.sh` (Zeile 134)
- `setup/modes/desktop/setup.sh` (Zeile 147)
- `setup/modes/custom/setup.sh` (Zeile 183)
- `core/init.sh` (Zeile 51, 190)

---

### 4. **Collect System Data** (`shell/scripts/setup/config/data-collection/collect-system-data.sh`)
**Was:** Backups von `configs/` Verzeichnis  
**Aktuell:**
- Zeile 22: `configs.backup.$(date +%s)` → `/etc/nixos/configs.backup.*`

**Problem:** Backup-Verzeichnis direkt in `/etc/nixos/`

---

### 5. **Setup Scripts** (server/desktop/custom)
**Was:** Backups von `configs/` Verzeichnis  
**Aktuell:**
- `server/setup.sh` Zeile 141: `configs.backup.$(date +%s)` → `/etc/nixos/configs.backup.*`
- `desktop/setup.sh` Zeile 154: `configs.backup.$(date +%s)` → `/etc/nixos/configs.backup.*`
- `custom/setup.sh` Zeile 190: `configs.backup.$(date +%s)` → `/etc/nixos/configs.backup.*`

**Problem:** Backup-Verzeichnisse direkt in `/etc/nixos/`

---

### 6. **System Update Handler** (`nixos/core/system-manager/handlers/system-update.nix`)
**Was:** Vollständiges Backup von `/etc/nixos/` vor System-Updates  
**Aktuell:**
- Zeile 495: `/var/backup/nixos/YYYY-MM-DD_HH-MM-SS/` ✅ **KORREKT!**
- Retention: Letzte 5 Backups (Zeile 503)

**Status:** ✅ **Bereits korrekt implementiert**

---

### 7. **Feature Migration** (`nixos/core/system-manager/handlers/feature-migration.nix`)
**Was:** Backups von `features-config.nix` vor Feature-Migrationen  
**Aktuell:**
- Zeile 23: `/var/backup/nixos/migrations/` ✅ **KORREKT!**
- Format: `${FEATURE_NAME}_${FROM_VERSION}_to_${TO_VERSION}_YYYYMMDD_HHMMSS.backup`

**Status:** ✅ **Bereits korrekt implementiert**

---

### 8. **SSH Server Manager** (`nixos/features/ssh-server-manager/scripts/`)
**Was:** Backups von `/etc/ssh/sshd_config`  
**Aktuell:**
- `approve-request.nix` Zeile 71: `/etc/ssh/sshd_config.backup.$(date +%s)`
- `grant-access.nix` Zeile 37: `/etc/ssh/sshd_config.backup.$(date +%s)`

**Problem:** Backups direkt neben der Datei (aber in `/etc/ssh/`, nicht `/etc/nixos/`)

**Empfehlung:** `/var/backup/nixos/ssh/sshd_config.backup.*`

---

### 9. **SSH Client Manager** (`nixos/features/ssh-client-manager/ssh-key-utils.nix`)
**Was:** Backups von SSH-Keys  
**Aktuell:**
- Zeile 82: `/home/$USER/.ssh/backups/YYYYMMDD_HHMMSS/` ✅ **KORREKT!**

**Status:** ✅ **Bereits korrekt implementiert** (User-spezifisch)

---

### 10. **System Discovery** (`nixos/features/system-discovery/restore.nix`)
**Was:** Backups von Browser-Daten  
**Aktuell:**
- Zeile 124: `places.sqlite.backup.$(date +%s)` → direkt neben der Datei
- Zeile 195: `Bookmarks.backup.$(date +%s)` → direkt neben der Datei

**Problem:** Backups direkt neben den Dateien (aber in User-Profilen, nicht `/etc/nixos/`)

**Empfehlung:** User-spezifische Backups sind OK, aber strukturierter wäre besser

---

## 🎯 MODERNE BACKUP-STANDARDS

### 1. **Zentrale Backup-Location**
- ✅ Alle System-Backups → `/var/backup/nixos/`
- ✅ User-Backups → `/home/$USER/.local/backups/` oder `/var/backup/nixos/users/$USER/`

### 2. **Strukturierte Verzeichnis-Hierarchie**
```
/var/backup/nixos/
├── configs/              # Config-Dateien Backups
│   ├── system-config.nix.backup.YYYYMMDD_HHMMSS
│   ├── desktop-config.nix.backup.YYYYMMDD_HHMMSS
│   └── ...
├── directories/          # Verzeichnis-Backups
│   ├── configs.YYYYMMDD_HHMMSS/
│   └── ...
├── migrations/           # Migrations-Backups (bereits korrekt)
│   └── feature_name_version_to_version_YYYYMMDD_HHMMSS.backup
├── ssh/                  # SSH-Config Backups
│   └── sshd_config.backup.YYYYMMDD_HHMMSS
└── system-updates/       # Vollständige System-Backups (bereits korrekt)
    └── YYYY-MM-DD_HH-MM-SS/
```

### 3. **Naming Convention**
- **Dateien:** `{original-name}.backup.YYYYMMDD_HHMMSS`
- **Verzeichnisse:** `{original-name}.YYYYMMDD_HHMMSS/`
- **Mit Kontext:** `{context}_{original-name}.backup.YYYYMMDD_HHMMSS`

### 4. **Retention Policy**
- **System-Updates:** Letzte 5 Backups (bereits implementiert)
- **Config-Migrationen:** Letzte 10 Backups
- **Feature-Migrationen:** Letzte 10 Backups
- **SSH-Config:** Letzte 5 Backups
- **Setup-Scripts:** Letzte 3 Backups

### 5. **Berechtigungen**
- `/var/backup/nixos/` → `root:root`, `700` (nur root)
- Automatische Bereinigung alter Backups

### 6. **Logging & Metadaten**
- Backup-Log: `/var/log/nixos-backups.log`
- Metadaten: `backup.json` in jedem Backup-Verzeichnis mit:
  - Timestamp
  - Original-Pfad
  - Backup-Grund (Migration, Update, etc.)
  - Checksum (optional)

---

## ✅ EMPFOHLENE IMPLEMENTIERUNG

### Zentrale Backup-Funktion
Erstelle eine zentrale Backup-Funktion in `nixos/core/system-manager/lib/backup-helpers.nix`:

```nix
backupConfigFile = originalPath: backupReason: ''
  BACKUP_ROOT="/var/backup/nixos/configs"
  BACKUP_FILE="$BACKUP_ROOT/$(basename "$originalPath").backup.$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$BACKUP_ROOT"
  cp "$originalPath" "$BACKUP_FILE"
  # Retention: Keep last 10
  ls -t "$BACKUP_ROOT"/$(basename "$originalPath").backup.* 2>/dev/null | tail -n +11 | xargs -r rm -f
'';
```

### Zu ändernde Dateien:

1. **`config-migration.nix`** (Zeilen 149, 372)
   - Von: `$SYSTEM_CONFIG.backup.*` in `/etc/nixos/`
   - Zu: `/var/backup/nixos/configs/system-config.nix.backup.*`

2. **`config-helpers.nix`** (Zeile 48)
   - Von: `${symlinkPath}.backup.*`
   - Zu: `/var/backup/nixos/configs/$(basename $symlinkPath).backup.*`

3. **`utils.sh`** (Zeile 60)
   - Von: `${file}.backup.*` neben der Datei
   - Zu: `/var/backup/nixos/configs/$(basename $file).backup.*` (wenn in `/etc/nixos/`)

4. **`collect-system-data.sh`** (Zeile 22)
   - Von: `configs.backup.*` in `/etc/nixos/`
   - Zu: `/var/backup/nixos/directories/configs.YYYYMMDD_HHMMSS/`

5. **Setup Scripts** (server/desktop/custom)
   - Von: `configs.backup.*` in `/etc/nixos/`
   - Zu: `/var/backup/nixos/directories/configs.YYYYMMDD_HHMMSS/`

6. **SSH Server Scripts**
   - Von: `/etc/ssh/sshd_config.backup.*`
   - Zu: `/var/backup/nixos/ssh/sshd_config.backup.*`

---

## 📊 ZUSAMMENFASSUNG

**Aktuell:**
- ❌ 8 Stellen erstellen Backups direkt in `/etc/nixos/`
- ✅ 2 Stellen verwenden bereits `/var/backup/nixos/` (system-update, feature-migration)
- ✅ 1 Stelle verwendet User-spezifischen Pfad (SSH keys)

**Sollte sein:**
- ✅ Alle System-Backups → `/var/backup/nixos/` mit strukturierter Hierarchie
- ✅ Retention Policy für alle Backup-Typen
- ✅ Zentrale Backup-Helper-Funktionen
- ✅ Automatische Bereinigung alter Backups

