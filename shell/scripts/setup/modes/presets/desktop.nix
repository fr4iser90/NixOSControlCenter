{
  #
  # Desktop Preset - Base Desktop Configuration
  # Minimal desktop setup without additional features
  #
  systemType = "desktop";
  hostName = null;  # Will be set from current hostname

  system = {
    channel = "stable";  # [stable/unstable] - Version wird in flake.nix definiert
    bootloader = "systemd-boot";
  };

  #
  # Package Modules - Empty (base desktop only)
  #
  packageModules = [];

  #
  # User Management - Will be set during setup
  # 
  users = {};

  #
  # Desktop Environment - Default settings
  #
  desktop = {
    enable = true;
    environment = "plasma";        # [plasma/gnome/xfce]
    display = {
      manager = "sddm";      # [sddm/gdm/lightdm]
      server = "wayland";    # [wayland/x11/hybrid]
      session = "plasma";          # [plasma/gnome]
    };
    theme = {
      dark = true;             # [true/false]
    };
    audio = "pipewire";
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
    ssh-server-manager = false;        
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
    enableSSH = null;
    enableSteam = false;
  };

  #
  # Hosting Configuration
  #
  email = "example@example.com";
  domain = "example.com";
}

