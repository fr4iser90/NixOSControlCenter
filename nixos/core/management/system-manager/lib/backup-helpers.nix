# Central backup helper functions
# Provides standardized backup functionality across the entire system

{ pkgs, lib, ... }:

rec {
  # Backup root directory
  backupRoot = "/var/backup/nixos";

  # Runtime shell function — use when the path is a bash variable ($cf, $sf, …).
  # Splicing backupConfigFile "$var" breaks under `set -u` (BACKUP_ROOT unbound).
  backupConfigFileFn = ''
    ncc_backup_config_file() {
      local original_path="''${1:-}"
      local _reason="''${2:-backup}"
      local backup_root="${backupRoot}/systemConfig"
      local backup_file
      if [ -z "$original_path" ] || [ ! -f "$original_path" ]; then
        return 0
      fi
      mkdir -p "$backup_root" 2>/dev/null || sudo mkdir -p "$backup_root" 2>/dev/null || true
      chmod 700 "$backup_root" 2>/dev/null || sudo chmod 700 "$backup_root" 2>/dev/null || true
      backup_file="$backup_root/$(basename "$original_path").backup.$(date +%Y%m%d_%H%M%S)"
      if cp "$original_path" "$backup_file" 2>/dev/null || sudo cp "$original_path" "$backup_file" 2>/dev/null; then
        chmod 600 "$backup_file" 2>/dev/null || sudo chmod 600 "$backup_file" 2>/dev/null || true
        ls -t "$backup_root"/$(basename "$original_path").backup.* 2>/dev/null | tail -n +11 | xargs -r rm -f 2>/dev/null || true
        echo "$backup_file"
        return 0
      fi
      return 0
    }
  '';

  # Backup a single config file (literal Nix path; self-contained snippet)
  backupConfigFile = originalPath: backupReason: ''
    BACKUP_ROOT="${backupRoot}/systemConfig"
    BACKUP_FILE="$BACKUP_ROOT/$(basename "${originalPath}").backup.$(date +%Y%m%d_%H%M%S)"
    if [ ! -d "$BACKUP_ROOT" ]; then
      mkdir -p "$BACKUP_ROOT"
      chmod 700 "$BACKUP_ROOT" 2>/dev/null || sudo chmod 700 "$BACKUP_ROOT" 2>/dev/null || true
      chown root:root "$BACKUP_ROOT" 2>/dev/null || sudo chown root:root "$BACKUP_ROOT" 2>/dev/null || true
    else
      mkdir -p "$BACKUP_ROOT"
    fi
    if cp "${originalPath}" "$BACKUP_FILE" 2>/dev/null || sudo cp "${originalPath}" "$BACKUP_FILE" 2>/dev/null; then
      chmod 600 "$BACKUP_FILE" 2>/dev/null || sudo chmod 600 "$BACKUP_FILE" 2>/dev/null || true
      chown root:root "$BACKUP_FILE" 2>/dev/null || sudo chown root:root "$BACKUP_FILE" 2>/dev/null || true
      ls -t "$BACKUP_ROOT"/$(basename "${originalPath}").backup.* 2>/dev/null | tail -n +11 | xargs -r rm -f 2>/dev/null || true
      echo "$BACKUP_FILE"
    else
      echo "" >&2
    fi
  '';

  # Backup a directory
  backupDirectory = originalPath: backupReason: ''
    BACKUP_ROOT="${backupRoot}/directories"
    BACKUP_DIR="$BACKUP_ROOT/$(basename "${originalPath}").$(date +%Y%m%d_%H%M%S)"

    if [ ! -d "$BACKUP_ROOT" ]; then
      mkdir -p "$BACKUP_ROOT"
      chmod 700 "$BACKUP_ROOT" 2>/dev/null || sudo chmod 700 "$BACKUP_ROOT" 2>/dev/null || true
      chown root:root "$BACKUP_ROOT" 2>/dev/null || sudo chown root:root "$BACKUP_ROOT" 2>/dev/null || true
    else
      mkdir -p "$BACKUP_ROOT"
    fi

    if cp -r "${originalPath}" "$BACKUP_DIR" 2>/dev/null || sudo cp -r "${originalPath}" "$BACKUP_DIR" 2>/dev/null; then
      chmod -R 700 "$BACKUP_DIR" 2>/dev/null || sudo chmod -R 700 "$BACKUP_DIR" 2>/dev/null || true
      find "$BACKUP_DIR" -type f -exec chmod 600 {} \; 2>/dev/null || sudo find "$BACKUP_DIR" -type f -exec chmod 600 {} \; 2>/dev/null || true
      chown -R root:root "$BACKUP_DIR" 2>/dev/null || sudo chown -R root:root "$BACKUP_DIR" 2>/dev/null || true
      ls -dt "$BACKUP_ROOT"/$(basename "${originalPath}").* 2>/dev/null | tail -n +6 | xargs -r rm -rf 2>/dev/null || true
      echo "$BACKUP_DIR"
    else
      echo "" >&2
    fi
  '';

  backupSSHConfig = originalPath: ''
    BACKUP_ROOT="${backupRoot}/ssh"
    BACKUP_FILE="$BACKUP_ROOT/$(basename "${originalPath}").backup.$(date +%Y%m%d_%H%M%S)"

    if [ ! -d "$BACKUP_ROOT" ]; then
      mkdir -p "$BACKUP_ROOT"
      chmod 700 "$BACKUP_ROOT" 2>/dev/null || sudo chmod 700 "$BACKUP_ROOT" 2>/dev/null || true
      chown root:root "$BACKUP_ROOT" 2>/dev/null || sudo chown root:root "$BACKUP_ROOT" 2>/dev/null || true
    else
      mkdir -p "$BACKUP_ROOT"
    fi

    if cp "${originalPath}" "$BACKUP_FILE" 2>/dev/null || sudo cp "${originalPath}" "$BACKUP_FILE" 2>/dev/null; then
      chmod 600 "$BACKUP_FILE" 2>/dev/null || sudo chmod 600 "$BACKUP_FILE" 2>/dev/null || true
      chown root:root "$BACKUP_FILE" 2>/dev/null || sudo chown root:root "$BACKUP_FILE" 2>/dev/null || true
      ls -t "$BACKUP_ROOT"/$(basename "${originalPath}").backup.* 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null || true
      echo "$BACKUP_FILE"
    else
      echo "" >&2
    fi
  '';

  backupFile = originalPath: backupReason: ''
    ORIGINAL_PATH="${originalPath}"

    if echo "$ORIGINAL_PATH" | grep -q "^/etc/ssh/"; then
      BACKUP_FILE=$(${backupSSHConfig originalPath})
    else
      BACKUP_FILE=$(${backupConfigFile originalPath backupReason})
    fi

    if [ -z "$BACKUP_FILE" ]; then
      echo "Failed to create backup of $ORIGINAL_PATH" >&2
      exit 1
    fi
  '';
}
