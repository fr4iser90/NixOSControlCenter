{ config, lib, pkgs, systemConfig, getModuleConfig, getCurrentModuleMetadata, ... }:

let
  moduleConfig = getCurrentModuleMetadata ./.;
  cfg = getModuleConfig moduleConfig.name;
  # Discovery: systemConfig/<configPath with . → />
  configDir = "/etc/nixos/systemConfig/${lib.replaceStrings [ "." ] [ "/" ] moduleConfig.configPath}";
  configFile = "${configDir}/config.nix";

  defaultConfig = ''
    # SSH Client Manager Configuration
    # This file contains SSH connection configurations

    {
      # Default SSH connections
      connections = {
        # Example connection - modify as needed
        # "server1" = {
        #   host = "192.168.1.100";
        #   user = "user";
        #   port = 22;
        #   identityFile = "~/.ssh/id_rsa";
        # };

        # Add your SSH connections here
      };

      # Default settings
      settings = {
        terminal = "kitty";  # Default terminal for SSH sessions
        editor = "nano";     # Default editor for config files
      };
    }
  '';

  # Do not use configHelpers from _module.args (infinite recursion).
  # Path comes from discovery metadata.configPath — never hardcode category dirs.
  activation = {
    system.activationScripts."${moduleConfig.name}-config-setup" = {
      text = ''
        mkdir -p "${configDir}"

        if [ ! -f "${configFile}" ]; then
          cat << 'EOF' > "${configFile}"
${defaultConfig}
EOF
          chmod 644 "${configFile}"
          echo "Created default config for ${moduleConfig.name}"
        fi
      '';
      deps = [];
    };
  };
in
{
  config = lib.mkIf (cfg.enable or false) (
    activation // {
      systemConfig.${moduleConfig.configPath}.enable = lib.mkDefault (cfg.enable or false);
    }
  );
}
