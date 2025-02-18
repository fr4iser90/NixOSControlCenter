{
  #
  # System Type & Profile
  #
  systemType = "desktop";
  hostName = "Gaming";

  system = {
    channel = "stable";  # oder "stable"
    version = "24.11";     # optional, für spezifische Version
    bootloader = "systemd-boot";
  };
  #
  # Packages Modules
  #
  packageModules = {
    gaming = {
      streaming = false;
      emulation = false;
    };
    development = {
      game = false;
      web = false;
    };
    server = {
      docker = false;
      web = false;
    };
  };

  #
  # User Management
  # 
  users = {
    "test" = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = false;
    };
    "test2" = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = false;
    };
  };

  #
  # Desktop Environment
  #
  desktop = {
    enable = true;
    environment = "plasma";
    display = {
      manager = "sddm";
      server = "wayland";
      session = "plasma";
    };
    theme = {
      dark = true;
    };
    audio = "pipewire";
  };

  #
  # Hardware Configuration
  #
  hardware = {
    cpu = "intel";
    gpu = "amd";
  };

  #
  # Nix Configuration
  #
  allowUnfree = true;
  buildLogLevel = "minimal";

  #
  # Features
  #
  features = {
    system-logger = false;     
    system-checks = false;      
    system-updater = false;   
    system-config-manager = false; 
    ssh-client-manager = false;
    ssh-server-manager = false;        
    bootentry-manager = false; 
    container-manager = false;  
    homelab-manager = false;    
    vm-manager = false;         
    ai-workspace = false;       
  };

  #
  # Localization
  #
  timeZone = "Europe/Berlin";
  locales = [ "en_US.UTF-8" ];
  keyboardLayout = "de";
  keyboardOptions = "eurosign";

  #
  # Profile Overrides
  #
  overrides = {
    enableSSH = null;
    enableSteam = true;
  };

  #
  # Hosting Configuration
  #
  email = "example@example.com";
  domain = "example.com";
}