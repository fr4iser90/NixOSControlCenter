{ config, lib, pkgs, ... }:

{
  config = {
    # Basic display server configuration
    services.xserver = {
      enable = true;
      displayManager.sessionCommands = ''
        ${pkgs.spice-vdagent}/bin/spice-vdagent
      '';
      # Set appropriate video driver based on detection
      videoDrivers = [
        "qxl"
        "virtio"
        "modesetting"  # Fallback
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
      # Basic 3D acceleration
      package = pkgs.mesa.drivers;
    };

    # VM-specific optimizations
    environment.systemPackages = with pkgs; [
      spice-vdagent  # Better mouse integration
      virtio-win     # Virtio drivers
      xorg.xrandr    # For resolution management
    ];
  };
}