{ config, lib, pkgs, ... }:

let
  env = import ../../../env.nix;
in {
  config = lib.mkIf (env.systemType == "gaming-workstation") {
    # Workstation-spezifische Konfiguration
    virtualisation.docker.enable = env.overrides.enableDocker or false;
    virtualisation.libvirtd.enable = env.overrides.enableVirtualization or false;
    # ... weitere Workstation-Einstellungen
  };
}