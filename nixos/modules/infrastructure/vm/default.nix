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
    virt-viewer
    spice
    spice-gtk
    spice-protocol
    swtpm
  ]);

  # NixOS libvirtd group is `libvirtd` (not `libvirt`)
  systemd.tmpfiles.rules = mkIf (cfg.enable or false) [
    "d ${stateDir} 0775 root libvirtd -"
    "d ${stateDir}/images 0775 root libvirtd -"
    "d ${stateDir}/testing 0775 root libvirtd -"
    "d ${stateDir}/testing/images 0775 root libvirtd -"
    "d ${stateDir}/testing/iso 0775 root libvirtd -"
    "d ${stateDir}/testing/vars 0775 root libvirtd -"
    "d ${stateDir}/testing/swtpm 0775 root libvirtd -"
  ];
}
