{
  #
  # System Type & Profile
  #
  systemType = "desktop";
  hostName = "Gaming";
  bootloader = "systemd-boot";

  #
  # Profile Modules
  #
  profileModules = {
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
  desktop = "plasma";
  displayManager = "sddm";
  displayServer = "wayland";
  session = "plasma";
  darkMode = true;

  #
  # Hardware Configuration
  #
  cpu = "intel";
  gpu = "amd";
  audio = "pipewire";

  #
  # Nix Configuration
  #
  allowUnfree = true;
  buildLogLevel = "minimal";

  #
  # System Features
  #
  entryManagement = true;
  preflightChecks = true;
  sshManager = true;
  flakeUpdater = true;

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
  email = "pa.boe90@gmail.com";
  domain = "fr4iserhome.com";
  certEmail = "pa.boe90@gmail.com";
}