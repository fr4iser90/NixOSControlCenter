# v1 modular systemConfig paths (single source of truth)
{
  root = "/etc/nixos/systemConfig";

  core = {
    base = {
      desktop = "/etc/nixos/systemConfig/core/base/desktop/config.nix";
      hardware = "/etc/nixos/systemConfig/core/base/hardware/config.nix";
      packages = "/etc/nixos/systemConfig/core/base/packages/config.nix";
      localization = "/etc/nixos/systemConfig/core/base/localization/config.nix";
      network = "/etc/nixos/systemConfig/core/base/network/config.nix";
      user = "/etc/nixos/systemConfig/core/base/user/config.nix";
      audio = "/etc/nixos/systemConfig/core/base/audio/config.nix";
    };
    management = {
      moduleManager = "/etc/nixos/systemConfig/core/management/module-manager/config.nix";
      systemManager = "/etc/nixos/systemConfig/core/management/system-manager/config.nix";
    };
  };
}
