{
  #
  # Server Preset - Base Server Configuration
  # Minimal server setup without additional features
  #
  systemType = "server";
  hostName = null;  # Will be set from current hostname

  system = {
    channel = "stable";  # [stable/unstable] - Version wird in flake.nix definiert
    bootloader = "systemd-boot";
  };

  #
  # Package Modules - Empty (base server only)
  #
  packageModules = [];

  #
  # User Management - Will be set during setup
  # 
  users = {};

  #
  # Desktop Environment - Disabled for server
  #
  desktop = {
    enable = false;
    environment = null;
    display = {
      manager = null;
      server = null;
      session = null;
    };
    theme = {
      dark = null;
    };
    audio = null;
  };

  #
  # Hardware Configuration - Will be detected
  #
  hardware = {
    cpu = null;  # Will be detected
    gpu = null;  # Will be detected
  };

  #
  # Nix Configuration
  #
  allowUnfree = false;
  buildLogLevel = "minimal";

  #
  # System Features - Base features only
  #
  features = {
    system-logger = true;     
    system-checks = true;      
    system-updater = true;    
    ssh-client-manager = false;
    ssh-server-manager = true;  # Server typically needs SSH
    bootentry-manager = false; 
    homelab-manager = false;    
    vm-manager = false;         
    ai-workspace = false;       
  };

  #
  # Localization - Default
  #
  timeZone = "Europe/Berlin";
  locales = [ "en_US.UTF-8" ];
  keyboardLayout = "de";
  keyboardOptions = "terminate";

  #
  # Profile Overrides
  #
  overrides = {
    enableSSH = true;  # Server typically needs SSH
    enableSteam = false;
  };

  #
  # Hosting Configuration
  #
  email = "example@example.com";
  domain = "example.com";
}

