{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

let
  # Single Source: Modulname nur einmal definieren
  moduleName = baseNameOf ./. ;  # ← hardware aus core/base/hardware/
  cfg = getModuleConfig moduleName;
in {
  _module.metadata = {
    role = "core";
    name = moduleName;
    description = "Hardware detection and configuration";
    category = "base";
    subcategory = "hardware";
    version = "1.0.0";
  };

  imports = [
    ./options.nix
    (import ./config.nix { inherit config lib getModuleConfig moduleName; })
    ./commands.nix
    ./components/gpu
    ./components/cpu
    ./components/memory
  ];

  # Global firmware for all hardware: WiFi (MediaTek, Intel, Broadcom, etc.),
  # Bluetooth, sound cards, and other devices that need proprietary firmware.
  # Previously only set for AMD GPU — now applies to all hosts.
  hardware.enableRedistributableFirmware = true;
}
