{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  priv = import ./scripts/privileged-helper.nix {
    inherit pkgs lib getModuleConfig getModuleMetadata;
  };
  privTests = import ./scripts/privileged-security-tests.nix {
    inherit pkgs lib getModuleConfig getModuleMetadata;
  };
in {
  imports = [
    ./options.nix
    ./config.nix
    ./commands.nix
  ];

  # When using an explicit `config` attr, `_module` must live inside it
  # (NixOS rejects mixed top-level `_module` + `config`).
  config = lib.mkMerge [
    {
      _module.metadata = {
        role = "core";
        name = moduleName;
        description = "NixOS Control Center - CLI ecosystem";
        category = "management";
        subcategory = "control-center";
        stability = "stable";
        version = "1.0.0";
      };
    }
    (lib.mkIf (cfg.enable or true) (lib.mkMerge [
      priv.nixosModule
      {
        environment.systemPackages = [ privTests ];
        environment.variables.NCC_USER_ROLES = "/etc/ncc/user-roles";
      }
    ]))
  ];
}
