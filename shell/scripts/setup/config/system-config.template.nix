{
  #
  # System Type & Profile
  #
  systemType = "@SYSTEM_TYPE@";
  hostName = "@HOSTNAME@";

  system = {
    channel = "stable";  # oder "stable"
    version = "25.05";     # optional, für spezifische Version
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
    audio = "pipewire";
  };

  #
  # Hardware Configuration
  #
  hardware = {
    cpu = "@CPU@";
    gpu = "@GPU@";
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
    system-logger = true;     
    system-checks = true;      
    system-updater = true;    
    ssh-client-manager = false;
    ssh-server-manager = false;        
    bootentry-manager = false;  
    homelab-manager = true;    
    vm-manager = false;         
    ai-workspace = false;       
  };

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
}