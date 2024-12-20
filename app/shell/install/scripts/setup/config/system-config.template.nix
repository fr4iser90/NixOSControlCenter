{
  #
  # System Type & Profile
  #
  systemType = "@SYSTEM_TYPE@";
  hostName = "@HOSTNAME@";
  bootloader = "@BOOTLOADER@";

  #
  # Profile Modules
  #
  profileModules = {
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
  desktop = "@DESKTOP@";
  displayManager = "@DISPLAY_MGR@";
  displayServer = "@DISPLAY_SERVER@";
  session = "@SESSION@";
  darkMode = @DARK_MODE@;

  #
  # Hardware Configuration
  #
  cpu = "@CPU@";
  gpu = "@GPU@";
  audio = "@AUDIO@";

  #
  # Nix Configuration
  #
  allowUnfree = @ALLOW_UNFREE@;
  buildLogLevel = "@BUILD_LOG_LEVEL@";

  #
  # System Features
  #
  entryManagement = @ENTRY_MANAGEMENT@;
  preflightChecks = @PREFLIGHT_CHECKS@;
  sshManager = @SSH_MANAGER@;
  flakeUpdater = @FLAKE_UPDATER@;

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