{
  #
  # System Type & Profile
  #
  systemType = "@SYSTEM_TYPE@";
  hostName = "@HOSTNAME@";

  system = {
    channel = "stable";  # oder "stable"
    version = "24.11";     # optional, für spezifische Version
    bootloader = "@BOOTLOADER@";
  };
  #
  # Packages Modules
  #
  packageModules = {
    gaming = {
      streaming = @GAMING_STREAMING@;
      emulation = @GAMING_EMULATION@;
    };
    development = {
      game = @DEV_GAME@;
      web = @DEV_WEB@;
    };
    server = {
      docker = @SERVER_DOCKER@;
      web = @SERVER_WEB@;
    };
  };

  #
  # User Management
  # 
  users = {
    @USERS@  
  };

  #
  # Desktop Environment
  #
  desktop = {
    enable = @ENABLE_DESKTOP@;
    environment = "@DESKTOP@";        # [plasma/gnome/xfce]
    display = {
      manager = "@DISPLAY_MGR@";      # [sddm/gdm/lightdm]
      server = "@DISPLAY_SERVER@";    # [wayland/x11/hybrid]
      session = "@SESSION@";          # [plasma/gnome]
    };
    theme = {
      dark = @DARK_MODE@;             # [true/false]
    };
  };

  #
  # Hardware Configuration
  #
  hardware = {
    cpu = "@CPU@";
    gpu = "@GPU@";
    audio = "@AUDIO@";
    # Weitere Hardware-Konfigurationen
  };

  #
  # Nix Configuration
  #
  allowUnfree = @ALLOW_UNFREE@;
  buildLogLevel = "@BUILD_LOG_LEVEL@";

  #
  # System Features
  #
  features = {
    system-logger = false;     
    system-checks = @SYSTEM_CHECKS@;      
    system-updater = false;    
    ssh-manager = @SSH_MANAGER@;        
    bootentry-manager = false; 
    homelab-manager = @HOMELAB_MANAGER@;    
    vm-manager = false;         
    ai-workspace = false;       
  };

  #
  # Security Settings
  #
  sudo = {
    requirePassword = @SUDO_REQUIRE_PASS@;
    timeout = @SUDO_TIMEOUT@;
  };
  enableFirewall = @ENABLE_FIREWALL@;

  #
  # Localization
  #
  timeZone = "@TIMEZONE@";
  locales = [ "@LOCALE@" ];
  keyboardLayout = "@KEYBOARD_LAYOUT@";
  keyboardOptions = "@KEYBOARD_OPTIONS@";

  #
  # Profile Overrides
  #
  overrides = {
    enableSSH = @OVERRIDE_SSH@;
    enableSteam = @OVERRIDE_STEAM@;
  };

  #
  # Hosting Configuration
  #
  email = "@EMAIL@";
  domain = "@DOMAIN@";
  certEmail = "@CERT_EMAIL@";
}