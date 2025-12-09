{
  # System Logging Configuration
  management = {
    logging = {
      enable = true;  # Enable system logging

      # Default detail level for all reports
      defaultDetailLevel = "info";

      # Collector-specific configurations
      collectors = {
        # System profile collector
        profile.enable = true;
        profile.detailLevel = null;  # Use default
        profile.priority = 100;

        # Bootloader information collector
        bootloader.enable = true;
        bootloader.detailLevel = null;
        bootloader.priority = 50;

        # Boot entry collector
        bootentries.enable = true;
        bootentries.detailLevel = null;
        bootentries.priority = 60;

        # Installed packages collector
        packages.enable = true;
        packages.detailLevel = null;
        packages.priority = 200;

        # Additional collectors (disabled by default)
        desktop.enable = false;
        desktop.detailLevel = null;
        desktop.priority = 300;

        network.enable = false;
        network.detailLevel = null;
        network.priority = 400;

        services.enable = false;
        services.detailLevel = null;
        services.priority = 500;

        sound.enable = false;
        sound.detailLevel = null;
        sound.priority = 600;

        system-config.enable = false;
        system-config.detailLevel = null;
        system-config.priority = 700;

        virtualization.enable = false;
        virtualization.detailLevel = null;
        virtualization.priority = 800;
      };
    };
  };
}
