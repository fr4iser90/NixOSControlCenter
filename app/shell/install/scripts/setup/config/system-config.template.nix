{
  #
  # System Type & Profile
  #
  systemType = "@SYSTEM_TYPE@";          # [desktop/server/minimal]
  hostName = "@HOSTNAME@";
  bootloader = "@BOOTLOADER@";

  #
  # Profile Modules
  #
  profileModules = {
    gaming = {
      streaming = @GAMING_STREAMING@;     # [true/false]
      emulation = @GAMING_EMULATION@;     # [true/false]
    };
    development = {
      game = @DEV_GAME@;                 # [true/false]
      web = @DEV_WEB@;                   # [true/false]
    };
    server = {
      docker = @SERVER_DOCKER@;          # [true/false]
      web = @SERVER_WEB@;               # [true/false]
    };
  };

  #
  # User Management
  # Wird durch das Script mit allen User-Einträgen ersetzt
  users = {
    @USERS@  
  };

  #
  # Desktop Environment
  #
  desktop = "@DESKTOP@";              # [plasma/gnome/xfce]
  displayManager = "@DISPLAY_MGR@";   # [sddm/gdm/lightdm]
  displayServer = "@DISPLAY_SERVER@"; # [wayland/x11/hybrid]
  session = "@SESSION@";              # [plasma/gnome]
  darkMode = @DARK_MODE@;            # [true/false]

  #
  # Hardware Configuration
  #
  cpu = "@CPU@";               
  gpu = "@GPU@";               
  audio = "@AUDIO@";          # [pipewire/pulseaudio]

  #
  # Nix Configuration
  #
  allowUnfree = @ALLOW_UNFREE@;           # [true/false]
  buildLogLevel = "@BUILD_LOG_LEVEL@";    # [minimal/standard/detailed/full]

  #
  # System Features
  #
  entryManagement = @ENTRY_MANAGEMENT@;   # [true/false]
  preflightChecks = @PREFLIGHT_CHECKS@;   # [true/false]
  sshManager = @SSH_MANAGER@;             # [true/false]
  flakeUpdater = @FLAKE_UPDATER@;         # [true/false]

  #
  # Security Settings
  #
  sudo = {
    requirePassword = @SUDO_REQUIRE_PASS@; # [true/false]
    timeout = @SUDO_TIMEOUT@;             # [minutes]
  };
  enableFirewall = @ENABLE_FIREWALL@;     # [true/false]

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
    enableSSH = @OVERRIDE_SSH@;          # [true/false/null]
    enableSteam = @OVERRIDE_STEAM@;      # [true/false/null]
  };
  #
  # Hosting Configuration
  #
  email = "@EMAIL@";
  domain = "@DOMAIN@";
  certEmail = "@CERT_EMAIL@";
}
