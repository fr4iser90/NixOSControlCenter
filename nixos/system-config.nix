{
  #
  # System Type & Profile
  #
  systemType = "desktop";
  hostName = "GamingBed";

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
    "fr4iser" = {
      role = "restricted-admin";
      defaultShell = "zsh";
      autoLogin = false;
    };  
  };

  #
  # Desktop Environment
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
  # Hardware Configuration
  #
  hardware = {
    cpu = "amd";
    gpu = "amd-amd";
  };

  #
  # Nix Configuration
  #
  allowUnfree = true;
  buildLogLevel = "minimal";

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
    container-manager = false;  
    homelab-manager = true;    
    vm-manager = false;         
    ai-workspace = false;       
  };

  #
  # Localization
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
    enableSteam = true;
  };

  #
  # Hosting Configuration
  #
  email = "example@example.com";
  domain = "example.com";
}