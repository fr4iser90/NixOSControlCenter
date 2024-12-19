{
  #
  # System Type & Profile
  #
  systemType = "desktop";    # desktop, server, minimal
  hostName = "Gaming";
  bootloader = "systemd-boot";

  #
  # Profile Modules
  #
  profileModules = {
    gaming = {
      streaming = false;     # true/false
      emulation = false;     # true/false
    };
    development = {
      game = false;                 # true/false
      web = false;                   # true/false
    };
    server = {
      docker = false;          # true/false
      web = false;               # true/false
    };
  };

  #
  # User Management
  # Wird durch das Script mit allen User-Einträgen ersetzt
  users = {
    "fr4iser" = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = false;
    };
    "botchi" = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = false;
    };

  };

  #
  # Desktop Environment
  #
  desktop = "plasma";              # plasma, gnome, xfce, etc.
  displayManager = "sddm";   # sddm, gdm, lightdm
  displayServer = "wayland"; # wayland, x11, hybrid
  session = "plasma";              # plasma, gnome, etc.
  darkMode = true;            # true/false

  #
  # Hardware Configuration
  #
  cpu = "intel";               
  gpu = "amd";               
  audio = "pipewire";          # pipewire, pulseaudio

  #
  # Nix Configuration
  #
  allowUnfree = true;           # true/false
  buildLogLevel = "minimal";    # minimal, standard, detailed, full

  #
  # System Features
  #
  entryManagement = true;   # true/false
  preflightChecks = true;   # true/false
  sshManager = true;             # true/false
  flakeUpdater = true;         # true/false

  #
  # Security Settings
  #
  sudo = {
    requirePassword = false; # true/false
    timeout = 15;             # minutes
  };
  enableFirewall = false;     # true/false

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
    enableSSH = null;          # true/false/null
    enableSteam = true;      # true/false/null
  };
}