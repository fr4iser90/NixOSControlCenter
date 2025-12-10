{ pkgs, lib, backupHelpers }:

let
  setupConfigFile = symlinkPath: userConfigFilePath: defaultConfig: ''
    mkdir -p "$(dirname "${symlinkPath}")"
    mkdir -p "$(dirname "${userConfigFilePath}")"

    # Create default config if it doesn't exist
    if [ ! -f "${userConfigFilePath}" ]; then
      cat << 'EOF' > "${userConfigFilePath}"
${defaultConfig}
EOF
      chmod 644 "${userConfigFilePath}"
    fi

    # Create or update symlink with backup
    if [ -L "${symlinkPath}" ] || [ -f "${symlinkPath}" ]; then
      CURRENT_TARGET=$(readlink -f "${symlinkPath}" 2>/dev/null || echo "")
      EXPECTED_TARGET=$(readlink -f "${userConfigFilePath}" 2>/dev/null || echo "")

      if [ "$CURRENT_TARGET" != "$EXPECTED_TARGET" ]; then
        # Backup existing file if it's not a symlink
        if [ -f "${symlinkPath}" ] && [ ! -L "${symlinkPath}" ]; then
          cp "${symlinkPath}" "${symlinkPath}.backup.$(date +%s)"
        fi
        # Update symlink
        ln -sfn "${userConfigFilePath}" "${symlinkPath}"
      fi
    else
      # Create new symlink
      ln -sfn "${userConfigFilePath}" "${symlinkPath}"
    fi
  '';

  # 🎯 NEW: Centralized module config creation
  # Creates activation scripts for config setup
  createModuleConfig = {
    moduleName,
    defaultConfig
  }: {
    system.activationScripts."${moduleName}-config-setup" = setupConfigFile
      "/etc/nixos/configs/${moduleName}-config.nix"
      "/etc/nixos/configs/${moduleName}-config.nix"
      defaultConfig;
  };
in
{
  inherit setupConfigFile createModuleConfig;
}
