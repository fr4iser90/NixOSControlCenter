# systemConfig paths (single source of truth)
# v2 dual layout: monolith (/etc/nixos/systemConfig.nix) or split (systemConfig/**/config.nix)
let
  layout = import ./config-layout.nix {};
in
{
  root = layout.absolute.split;
  monolith = layout.absolute.monolith;
  layout = layout;

  # Pre-v1 leftover — must never remain after config-check / system-update
  legacy = {
    configsDir = "/etc/nixos/configs";
    systemConfigNix = "/etc/nixos/system-config.nix"; # v0 flat monolith
  };

  core = {
    base = {
      desktop = layout.splitConfigFile "core/base/desktop";
      hardware = layout.splitConfigFile "core/base/hardware";
      packages = layout.splitConfigFile "core/base/packages";
      localization = layout.splitConfigFile "core/base/localization";
      network = layout.splitConfigFile "core/base/network";
      user = layout.splitConfigFile "core/base/user";
      audio = layout.splitConfigFile "core/base/audio";
    };
    management = {
      moduleManager = layout.splitConfigFile "core/management/module-manager";
      systemManager = layout.splitConfigFile "core/management/system-manager";
    };
  };
}
