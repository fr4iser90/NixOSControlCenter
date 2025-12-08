# Central helper functions for config file management
# Used by all modules to create default configs and manage symlinks

{ pkgs, lib, backupHelpers, ... }:

rec {
  # Create default config file if it doesn't exist
  # Usage: createDefaultConfig userConfigFile defaultContent symlinkPath
  # CRITICAL: Prüft auch Symlink, um User-Configs zu schützen
  createDefaultConfig = userConfigFile: defaultContent: symlinkPath: ''
    # CRITICAL: Nur erstellen wenn Datei NICHT existiert
    if [ ! -f "${toString userConfigFile}" ]; then
      # Datei existiert nicht → erstelle Default
      mkdir -p "$(dirname "${toString userConfigFile}")"
      cat > "${toString userConfigFile}" <<'EOF'
${defaultContent}
EOF
    fi
  '';

  # Create/update symlink from /etc/nixos/configs/ to module user-configs/
  # Usage: createSymlink symlinkPath userConfigFile
  createSymlink = symlinkPath: userConfigFile: ''
    # Create/Update symlink
    if [ -L "${symlinkPath}" ] || [ -f "${symlinkPath}" ]; then
      # Check if symlink points to correct file
      CURRENT_TARGET=$(readlink -f "${symlinkPath}" 2>/dev/null || echo "")
      EXPECTED_TARGET=$(readlink -f "${toString userConfigFile}" 2>/dev/null || echo "")
      
      if [ "$CURRENT_TARGET" != "$EXPECTED_TARGET" ]; then
        # Backup old config if it was a real file
        if [ -f "${symlinkPath}" ] && [ ! -L "${symlinkPath}" ]; then
          # Use centralized backup helper
          ${backupHelpers.backupConfigFile "${symlinkPath}" "symlink-update"} >/dev/null 2>&1 || true
        fi
        # Create new symlink
        ln -sfn "${toString userConfigFile}" "${symlinkPath}"
      fi
    else
      # Symlink doesn't exist, create it
      ln -sfn "${toString userConfigFile}" "${symlinkPath}"
    fi
  '';

  # Combined: Create default config + symlink
  # Usage: setupConfigFile symlinkPath userConfigFile defaultContent
  # CRITICAL: Prüft Symlink vor Erstellung, um User-Configs zu schützen
  setupConfigFile = symlinkPath: userConfigFile: defaultContent: ''
    mkdir -p "$(dirname "${symlinkPath}")"
    
    # Prüfe ob User-Config existiert (via Symlink oder direkt)
    ${createDefaultConfig userConfigFile defaultContent symlinkPath}
    
    # Erstelle/Update Symlink (auch wenn Default nicht erstellt wurde)
    ${createSymlink symlinkPath userConfigFile}
  '';
}

