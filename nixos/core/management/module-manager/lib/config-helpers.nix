# External config creation - automatic default configs!
# Creates activation scripts for external config setup
{ pkgs, lib }:

let
  # Get module info from current directory
  getModuleInfo = modulePath: rec {
    # Extract name from directory name
    name = lib.last (lib.splitString "/" (toString modulePath));

    # Extract category from parent directory
    category = lib.last (lib.splitString "/" (toString (dirOf modulePath)));

    # Extract parent category (modules/core/etc)
    parentCategory = lib.last (lib.splitString "/" (toString (dirOf (dirOf modulePath))));

    # Auto-generated paths
    fullPath = "${parentCategory}.${category}.${name}";
    optionsPath = fullPath;
    configPath = fullPath;
  };

  # Module configuration factory
  mkModuleConfig = modulePath: let
    info = getModuleInfo modulePath;
  in {
    # Module metadata
    inherit (info) name category parentCategory fullPath optionsPath configPath;

    # Utility functions
    mkOptionsPath = "options.${info.optionsPath}";
    mkConfigPath = "config.${info.configPath}";
  };


  createModuleConfig = { moduleName, defaultConfig }: {
    system.activationScripts."${moduleName}-config-setup" = {
      text = ''
        mkdir -p "/etc/nixos/configs/modules/specialized/${moduleName}"

        # Create default config if it doesn't exist
        if [ ! -f "/etc/nixos/configs/modules/specialized/${moduleName}/config.nix" ]; then
          cat << 'EOF' > "/etc/nixos/configs/modules/specialized/${moduleName}/config.nix"
${defaultConfig}
EOF
          chmod 644 "/etc/nixos/configs/modules/specialized/${moduleName}/config.nix"
          echo "Created default config for ${moduleName}"
        fi
      '';
      deps = [];
    };
  };
in
{
  inherit createModuleConfig mkModuleConfig getModuleInfo;
}
