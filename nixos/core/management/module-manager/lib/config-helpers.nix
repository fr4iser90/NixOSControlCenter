{ pkgs, lib, backupHelpers }:

# 🎯 External config creation - no more symlinks!
# Creates activation scripts for external config setup
createModuleConfig = {
  moduleName,
  defaultConfig
}: {
  system.activationScripts."${moduleName}-config-setup" = ''
    mkdir -p "/etc/nixos/configs"

    # Create default config if it doesn't exist
    if [ ! -f "/etc/nixos/configs/${moduleName}-config.nix" ]; then
      cat << 'EOF' > "/etc/nixos/configs/${moduleName}-config.nix"
${defaultConfig}
EOF
      chmod 644 "/etc/nixos/configs/${moduleName}-config.nix"
    fi
  '';
};
in
{
  inherit createModuleConfig;
}
