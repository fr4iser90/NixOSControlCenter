{ config, lib, pkgs, ... }:

{
  config = {
    # Basic display server configuration
    services.xserver = {
      enable = true;
      
      # Auto-detect virtual display driver
      videoDrivers = lib.mkDefault (
        if config.virtualisation.qemu.enable then
          (if config.virtualisation.spiceAgent.enable then [ "qxl" ] else [ "virtio" ])
        else
          [ "modesetting" ]
      );

      # Basic display settings
      displayManager = {
        # Use simple display manager for VMs
        lightdm.enable = true;
        # Default resolution
        sessionCommands = ''
          xrandr --output Virtual-1 --mode 1920x1080
        '';
      };
    };


    # Enable QXL and Virtio GPU support
    hardware.opengl = {
      enable = true;
      driSupport = true;
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