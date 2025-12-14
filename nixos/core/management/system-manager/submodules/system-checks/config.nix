{ config, lib, pkgs, systemConfig, ... }:

let
  configHelpers = import ../../../module-manager/lib/config-helpers.nix { inherit pkgs lib; };
  # Use the template file as default config
  defaultConfig = builtins.readFile ./checks-config.nix;

  cfg = config.core.management.system-manager.submodules.system-checks or {};
  # CLI formatter API
  ui = config.core.management.system-manager.submodules.cli-formatter.api;

  # Import scripts from scripts/ directory
  postbuildScript = import ./scripts/postbuild-checks.nix { inherit config lib pkgs systemConfig; };
  prebuildCheckScript = import ./scripts/prebuild-checks.nix { inherit config lib pkgs systemConfig; };

  # Postbuild checks implementation (moved from postbuild/default.nix)
  postbuildCfg = cfg.postbuild or {};

  # Prebuild checks implementation (moved from prebuild/default.nix)
  prebuildCfg = cfg.prebuild or {};
in
{
  imports = lib.optional true ./prebuild/checks/hardware/utils.nix
          ++ lib.optional true ./prebuild/checks/hardware/gpu.nix
          ++ lib.optional true ./prebuild/checks/hardware/cpu.nix
          ++ lib.optional true ./prebuild/checks/hardware/memory.nix
          ++ lib.optional true ./prebuild/checks/system/users.nix;

  config = lib.mkMerge [
    (lib.mkIf (cfg.enable or true)
      (configHelpers.createModuleConfig {
        moduleName = "checks";
        defaultConfig = defaultConfig;
      })
    )
    (lib.mkIf (cfg.enable or true) {
      # Module implementation (only when enabled)
      environment.systemPackages = with pkgs; [
        pciutils
        usbutils
        lshw
        prebuildCheckScript
      ] ++ lib.optional (postbuildCfg.enable or true) postbuildScript;

      # Postbuild activation script
      system.activationScripts.postbuildChecks = lib.mkIf (postbuildCfg.enable or true) {
        deps = [ "users" "groups" ];
        text = ''
          echo "Running postbuild checks..."
          ${postbuildScript}/bin/nixos-postbuild
        '';
      };
    })
  ];
}