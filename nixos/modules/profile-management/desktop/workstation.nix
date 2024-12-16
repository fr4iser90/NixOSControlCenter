{ config, lib, pkgs, systemConfig, ... }:
{
  config = lib.mkIf (systemConfig.systemType == "gaming-workstation") {
    # Workstation-spezifische Konfiguration
    virtualisation.docker.enable = systemConfig.overrides.enableDocker or false;
    virtualisation.libvirtd.enable = systemConfig.overrides.enableVirtualization or false;
    # ... weitere Workstation-Einstellungen
  };
}