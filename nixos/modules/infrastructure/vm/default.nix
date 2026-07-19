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

  # Host KVM + libvirt stack (deterministic — no manual modprobe/chown)
  boot.kernelModules = mkIf (cfg.enable or false) [ "kvm-intel" "kvm-amd" ];

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
  # Mode 2775 = setgid so new files inherit the group
  systemd.tmpfiles.rules = mkIf (cfg.enable or false) [
    "d ${stateDir} 2775 root libvirtd -"
    "d ${stateDir}/images 2775 root libvirtd -"
    "d ${stateDir}/testing 2775 root libvirtd -"
    "d ${stateDir}/testing/images 2775 root libvirtd -"
    "d ${stateDir}/testing/iso 2775 root libvirtd -"
    "d ${stateDir}/testing/vars 2775 root libvirtd -"
  ];

  # Heal permissions on every switch (covers leftover root-owned files from earlier runs)
  system.activationScripts.nccVmStateDir = mkIf (cfg.enable or false) (
    stringAfter [ "users" "groups" ] ''
      install -d -m 2775 -o root -g libvirtd ${stateDir}
      install -d -m 2775 -o root -g libvirtd ${stateDir}/images
      install -d -m 2775 -o root -g libvirtd ${stateDir}/testing
      install -d -m 2775 -o root -g libvirtd ${stateDir}/testing/images
      install -d -m 2775 -o root -g libvirtd ${stateDir}/testing/iso
      install -d -m 2775 -o root -g libvirtd ${stateDir}/testing/vars
      chgrp -R libvirtd ${stateDir} 2>/dev/null || true
      find ${stateDir} -type d -exec chmod 2775 {} + 2>/dev/null || true
      find ${stateDir} -type f -exec chmod g+rw {} + 2>/dev/null || true
    ''
  );
}
