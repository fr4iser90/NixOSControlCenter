{ config, lib, pkgs, systemConfig, ... }:
let
  configHelpers = import ../../management/module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./user-config.nix;
in
{
  config = lib.mkIf ((systemConfig.system.user.enable or false) || true)
    (lib.recursiveUpdate
      (configHelpers.createModuleConfig {
        moduleName = "user";
        defaultConfig = defaultConfig;
      })
      {
        # Replace placeholder with actual username
        system.activationScripts."user-config-personalize" = ''
          if [ -f "/etc/nixos/configs/user-config.nix" ]; then
            # Replace yourusername with actual user from whoami
            REAL_USER=$(whoami)
            sed -i "s/yourusername/$REAL_USER/g" "/etc/nixos/configs/user-config.nix"
          fi
        '';
      }
    );

  # User module implementation is handled in default.nix
}
