{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  parent = getModuleConfig "ssh-manager";
  cfg = parent.client or {};
  configDir = "/etc/nixos/systemConfig/modules/security/ssh-manager";
  configFile = "${configDir}/client-connections.nix";

  defaultConfig = ''
    # SSH client connection store (used by ncc ssh client)
    {
      connections = {
        # "server1" = {
        #   host = "192.168.1.100";
        #   user = "user";
        #   port = 22;
        #   identityFile = "~/.ssh/id_rsa";
        # };
      };
      settings = {
        terminal = "kitty";
        editor = "nano";
      };
    }
  '';
in {
  config = lib.mkIf (cfg.enable or false) {
    system.activationScripts."ssh-manager-client-config-setup" = {
      text = ''
        mkdir -p "${configDir}"
        if [ ! -f "${configFile}" ]; then
          cat << 'EOF' > "${configFile}"
${defaultConfig}
EOF
          chmod 644 "${configFile}"
          echo "Created default SSH client connections store"
        fi
      '';
      deps = [];
    };
  };
}
