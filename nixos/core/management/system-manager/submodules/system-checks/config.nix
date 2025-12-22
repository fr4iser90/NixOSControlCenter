{ config, lib, pkgs, systemConfig, ... }:

let
  # CLI formatter API
  ui = {}; # Temporarily disable UI

  # Import scripts from scripts/ directory

  # Postbuild checks config
  postbuildCfg = {};

  # Prebuild checks config
  prebuildCfg = {};
in
{
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