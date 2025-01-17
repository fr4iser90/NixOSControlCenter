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
  # Profile Modules
  #
  packageModules = {
    gaming = {
      streaming = true;
      emulation = true;
    };
    development = {
      game = true;
      web = true;
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
    memory = {
      sizeGB = 32;
    };
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
    system-logger = false;      # Optional
    system-checks = false;      # Optional
    system-updater = false;     # Optional
    ssh-client-manager = false; # Optional
    ssh-server-manager = false; # Optional
    bootentry-manager = false;  # Optional
    container-manager = true;  # Optional
    homelab-manager = false;    # Optional
    vm-manager = false;         # Optional
    ai-workspace = false;       # Optional
    tracker = true;
  };

  #
  # Security Settings
  #
  sudo = {
    requirePassword = false;
    timeout = 15;
  };
  enableFirewall = false;

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
  certEmail = "example@example.com";
}
