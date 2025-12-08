# Central backup helper functions
# Provides standardized backup functionality across the entire system

{ pkgs, lib, ... }:

rec {
  # Backup root directory
  backupRoot = "/var/backup/nixos";
  
  # Backup a single config file
  # Usage: backupConfigFile originalPath backupReason
  # Example: backupConfigFile "/etc/nixos/system-config.nix" "migration"
  backupConfigFile = originalPath: backupReason: ''
    BACKUP_ROOT="${backupRoot}/configs"
    BACKUP_FILE="$BACKUP_ROOT/$(basename "$originalPath").backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create directory if it doesn't exist (ActivationScript should have created it)
    if [ ! -d "$BACKUP_ROOT" ]; then
      mkdir -p "$BACKUP_ROOT"
      chmod 700 "$BACKUP_ROOT" 2>/dev/null || sudo chmod 700 "$BACKUP_ROOT" 2>/dev/null || true
      chown root:root "$BACKUP_ROOT" 2>/dev/null || sudo chown root:root "$BACKUP_ROOT" 2>/dev/null || true
    else
      mkdir -p "$BACKUP_ROOT"  # Ensure it exists
    fi
    
    # Create backup file and set permissions (600 = read/write for owner only)
    if cp "$originalPath" "$BACKUP_FILE" 2>/dev/null || sudo cp "$originalPath" "$BACKUP_FILE" 2>/dev/null; then
      chmod 600 "$BACKUP_FILE" 2>/dev/null || sudo chmod 600 "$BACKUP_FILE" 2>/dev/null || true
      chown root:root "$BACKUP_FILE" 2>/dev/null || sudo chown root:root "$BACKUP_FILE" 2>/dev/null || true
      # Cleanup old backups (keep last 10)
      ls -t "$BACKUP_ROOT"/$(basename "$originalPath").backup.* 2>/dev/null | tail -n +11 | xargs -r rm -f 2>/dev/null || sudo xargs -r rm -f 2>/dev/null || true
      echo "$BACKUP_FILE"
      return 0
    else
      echo "" >&2
      return 1
    fi
  '';
  
  # Backup a directory
  # Usage: backupDirectory originalPath backupReason
  # Example: backupDirectory "/etc/nixos/configs" "setup"
  backupDirectory = originalPath: backupReason: ''
    BACKUP_ROOT="${backupRoot}/directories"
    BACKUP_DIR="$BACKUP_ROOT/$(basename "$originalPath").$(date +%Y%m%d_%H%M%S)"
    
    # Create directory if it doesn't exist (ActivationScript should have created it)
    if [ ! -d "$BACKUP_ROOT" ]; then
      mkdir -p "$BACKUP_ROOT"
      chmod 700 "$BACKUP_ROOT" 2>/dev/null || sudo chmod 700 "$BACKUP_ROOT" 2>/dev/null || true
      chown root:root "$BACKUP_ROOT" 2>/dev/null || sudo chown root:root "$BACKUP_ROOT" 2>/dev/null || true
    else
      mkdir -p "$BACKUP_ROOT"  # Ensure it exists
    fi
    
    # Create backup directory and set permissions (700 for dirs, 600 for files)
    if cp -r "$originalPath" "$BACKUP_DIR" 2>/dev/null || sudo cp -r "$originalPath" "$BACKUP_DIR" 2>/dev/null; then
      chmod -R 700 "$BACKUP_DIR" 2>/dev/null || sudo chmod -R 700 "$BACKUP_DIR" 2>/dev/null || true
      find "$BACKUP_DIR" -type f -exec chmod 600 {} \; 2>/dev/null || sudo find "$BACKUP_DIR" -type f -exec chmod 600 {} \; 2>/dev/null || true
      chown -R root:root "$BACKUP_DIR" 2>/dev/null || sudo chown -R root:root "$BACKUP_DIR" 2>/dev/null || true
      # Cleanup old backups (keep last 5)
      ls -dt "$BACKUP_ROOT"/$(basename "$originalPath").* 2>/dev/null | tail -n +6 | xargs -r rm -rf 2>/dev/null || sudo xargs -r rm -rf 2>/dev/null || true
      echo "$BACKUP_DIR"
      return 0
    else
      echo "" >&2
      return 1
    fi
  '';
  
  # Backup SSH config file
  # Usage: backupSSHConfig originalPath
  # Example: backupSSHConfig "/etc/ssh/sshd_config"
  backupSSHConfig = originalPath: ''
    BACKUP_ROOT="${backupRoot}/ssh"
    BACKUP_FILE="$BACKUP_ROOT/$(basename "$originalPath").backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create directory if it doesn't exist (ActivationScript should have created it)
    if [ ! -d "$BACKUP_ROOT" ]; then
      mkdir -p "$BACKUP_ROOT"
      chmod 700 "$BACKUP_ROOT" 2>/dev/null || sudo chmod 700 "$BACKUP_ROOT" 2>/dev/null || true
      chown root:root "$BACKUP_ROOT" 2>/dev/null || sudo chown root:root "$BACKUP_ROOT" 2>/dev/null || true
    else
      mkdir -p "$BACKUP_ROOT"  # Ensure it exists
    fi
    
    # Create backup file and set permissions (600 = read/write for owner only)
    if cp "$originalPath" "$BACKUP_FILE" 2>/dev/null || sudo cp "$originalPath" "$BACKUP_FILE" 2>/dev/null; then
      chmod 600 "$BACKUP_FILE" 2>/dev/null || sudo chmod 600 "$BACKUP_FILE" 2>/dev/null || true
      chown root:root "$BACKUP_FILE" 2>/dev/null || sudo chown root:root "$BACKUP_FILE" 2>/dev/null || true
      # Cleanup old backups (keep last 5)
      ls -t "$BACKUP_ROOT"/$(basename "$originalPath").backup.* 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null || sudo xargs -r rm -f 2>/dev/null || true
      echo "$BACKUP_FILE"
      return 0
    else
      echo "" >&2
      return 1
    fi
  '';
  
  # Generic backup function (for any file)
  # Automatically detects if it's a config file or SSH config
  # Usage: backupFile originalPath backupReason
  backupFile = originalPath: backupReason: ''
    ORIGINAL_PATH="$originalPath"
    
    # Determine backup location based on file path
    if echo "$ORIGINAL_PATH" | grep -q "^/etc/ssh/"; then
      # SSH config → use SSH backup
      BACKUP_FILE=$(${backupSSHConfig originalPath})
    elif echo "$ORIGINAL_PATH" | grep -q "^/etc/nixos/"; then
      # NixOS config → use config backup
      BACKUP_FILE=$(${backupConfigFile originalPath backupReason})
    else
      # Generic file → use config backup location
      BACKUP_FILE=$(${backupConfigFile originalPath backupReason})
    fi
    
    if [ -z "$BACKUP_FILE" ]; then
      echo "Failed to create backup of $ORIGINAL_PATH" >&2
      exit 1
    fi
  '';
}

