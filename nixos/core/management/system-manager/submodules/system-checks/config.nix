{ config, lib, pkgs, systemConfig, getModuleApi, ... }:

let
  # Import scripts from scripts/ directory

  # Postbuild checks config
  postbuildCfg = {};

  # Prebuild checks config
  prebuildCfg = {};
in
{
  # Pass getModuleApi to check modules
  _module.args = {
    inherit getModuleApi;
  };

  imports = [
    ./prebuild/checks/hardware/utils.nix
    ./prebuild/checks/hardware/gpu.nix
    ./prebuild/checks/hardware/cpu.nix
    ./prebuild/checks/hardware/memory.nix
    ./prebuild/checks/system/users.nix
  ];

  # Module implementation
      environment.systemPackages = with pkgs; [
        pciutils
        usbutils
        lshw
      ];
}