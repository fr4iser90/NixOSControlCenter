{
  # System Logging Configuration
  core = {
    management = {
    logging = {
      enable = true;  # Enable system logging

      # Default detail level for all reports
      defaultDetailLevel = "info";

      # Collector-specific configurations
      collectors = {
        # System profile collector
        profile = {
          enable = true;
          detailLevel = null;  # Use default
          priority = 100;
        };

        # Bootloader information collector
        bootloader = {
          enable = true;
          detailLevel = null;
          priority = 50;
        };

        # Boot entry collector
        bootentries = {
          enable = true;
          detailLevel = null;
          priority = 60;
        };

        # Installed packages collector
        packages = {
          enable = true;
          detailLevel = null;
          priority = 200;
        };

        # Additional collectors (disabled by default)
        desktop = {
          enable = false;
          detailLevel = null;
          priority = 300;
        };

        network = {
          enable = false;
          detailLevel = null;
          priority = 400;
        };

        services = {
          enable = false;
          detailLevel = null;
          priority = 500;
        };

        sound = {
          enable = false;
          detailLevel = null;
          priority = 600;
        };

        system-config = {
          enable = false;
          detailLevel = null;
          priority = 700;
        };

        virtualization = {
          enable = false;
          detailLevel = null;
          priority = 800;
        };
      };
    };
    };
  };
}
