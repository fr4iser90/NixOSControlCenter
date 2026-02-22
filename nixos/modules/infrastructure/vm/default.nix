{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

with lib;

let
  # CONVENTION OVER CONFIGURATION - Vollständig dynamisch aus Dateisystem
  moduleName = baseNameOf ./. ;        # "vm" - automatisch!
  cfg = getModuleConfig moduleName;
  stateDir = cfg.stateDir;
in {
  imports = [
    ./options.nix
    # Import commands.nix as function to pass moduleName (prevents infinite recursion)
    (import ./commands.nix { inherit config lib pkgs systemConfig getModuleConfig getModuleApi; moduleName = moduleName; })
  ] ++ optional (cfg.enable or false) (import ./testing { inherit config lib pkgs systemConfig getModuleConfig; });

  # Removed: Redundant enable setting (already defined in options.nix)

  virtualisation = mkIf (cfg.enable or false) {
    libvirtd.enable = true;
    libvirtd.allowedBridges = [ "virbr0" ];
    spiceUSBRedirection.enable = true;
  };

  programs.virt-manager.enable = mkIf (cfg.enable or false) true;

  environment.systemPackages = mkIf (cfg.enable or false) (with pkgs; [
    qemu
    virt-manager
    spice
    spice-gtk
    spice-protocol
    swtpm
  ]);

  systemd.tmpfiles.rules = mkIf (cfg.enable or false) [
    "d ${stateDir} 0755 root root -"
    "d ${stateDir}/images 0775 root libvirt -"
    "d ${stateDir}/testing 0775 root libvirt -"
  ];
}
