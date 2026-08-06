{ config, lib, pkgs, ... }:

{
  config = {
    # Basic display server configuration
    services.xserver = {
      enable = true;
      displayManager.sessionCommands = ''
        ${pkgs.spice-vdagent}/bin/spice-vdagent
      '';
      # qxl = SPICE/QXL Xorg driver; virtio-gpu uses kernel DRM + modesetting
      # (there is no xf86 "virtio" videoDrivers entry — NixOS asserts on unknown names)
      videoDrivers = [
        "qxl"
        "modesetting"
      ];
    };

    virtualisation.spiceUSBRedirection.enable = true;

    # Enable SPICE agent service
    services.spice-vdagentd.enable = true;
    services.spice-webdavd.enable = true;
    services.gvfs.enable = true;
    # Enable QXL and Virtio GPU support
    hardware.graphics = {
      enable = true;
      package = pkgs.mesa;
    };

    # VM-specific optimizations
    environment.systemPackages = with pkgs; [
      spice-vdagent  # Better mouse integration
      xrandr         # For resolution management
    ];
  };
}