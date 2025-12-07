# Central helper functions for config file management
# Used by all modules to create default configs and manage symlinks

{ pkgs, lib, ... }:

rec {
  # Create default config file if it doesn't exist
  # Usage: createDefaultConfig userConfigFile defaultContent
  createDefaultConfig = userConfigFile: defaultContent: ''
    # Create default config if it doesn't exist
    if [ ! -f "${toString userConfigFile}" ]; then
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
          cp "${symlinkPath}" "${symlinkPath}.backup.$(date +%s)"
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
  setupConfigFile = symlinkPath: userConfigFile: defaultContent: ''
    mkdir -p "$(dirname "${symlinkPath}")"
    
    ${createDefaultConfig userConfigFile defaultContent}
    ${createSymlink symlinkPath userConfigFile}
  '';
}

