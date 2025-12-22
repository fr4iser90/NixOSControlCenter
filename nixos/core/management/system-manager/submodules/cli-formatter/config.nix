{ config, lib, pkgs, systemConfig, getModuleConfig, ... }:

let
  cfg = getModuleConfig "cli-formatter";

  colors = import ./colors.nix;

  core = import ./core {
    inherit lib colors;
    inherit (cfg) config;
  };

  components = import ./components {
    inherit lib colors;
    inherit (cfg) config;
  };

  interactive = import ./interactive {
    inherit lib colors;
    inherit (cfg) config;
  };

  status = import ./status {
    inherit lib colors;
    inherit (cfg) config;
  };

  # API definition - always available
  apiValue = {
    inherit colors;
    inherit (core) text layout;
    inherit (components) lists tables progress boxes;
    inherit (interactive) prompts spinners;
    inherit (status) messages badges;
  };

  configHelpers = import ../../../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./cli-formatter-config.nix;

in
  lib.mkMerge [
    (lib.mkIf (cfg.enable or true) (
      (configHelpers.createModuleConfig {
        moduleName = "cli-formatter";
        defaultConfig = defaultConfig;
      }) // {
        # API unter .api definieren (wie andere Module)
        core.management.system-manager.submodules.cli-formatter = {};
        core.management.system-manager.submodules.cli-formatter.api = apiValue;
      }
    ))
  ]
