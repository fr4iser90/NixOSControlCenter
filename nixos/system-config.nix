{
  #
  # System Type & Profile
  #
  systemType = "desktop";    # Determines the system profile
  hostName = "Gaming";       # System hostname
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
  #
  users = {
    "test" = {
      role = "admin";          # Full system access
      defaultShell = "zsh";
      autoLogin = true;
    };
    "test2" = {
      role = "restricted-admin"; # Limited admin privileges
      defaultShell = "zsh";
      autoLogin = false;
    };
    "test3" = {
      role = "guest";          # Basic user access
      defaultShell = "zsh";
      autoLogin = false;
    };
    "docker" = {
      role = "virtualization"; # Container management access
      defaultShell = "zsh";
      autoLogin = false;
    };
  };

  #
  # Desktop Environment
  #
  desktop = "plasma";          # KDE Plasma desktop
  displayManager = "sddm";     # Simple Desktop Display Manager
  displayServer = "wayland";   # Options: "x11", "wayland", "hybrid"
  session = "plasma";
  darkMode = true;            # Enable dark theme

  #
  # Hardware Configuration
  #
  cpu = "amd";               # Processor vendor
  gpu = "amd";               # Graphics card vendor
  audio = "pipewire";        # Modern audio system

  #
  # Nix Configuration
  #
  allowUnfree = true;        # Allow proprietary software
  buildLogLevel = "minimal"; # Options: "detailed", "standard", "minimal", "full"

  #
  # System Features
  #
  entryManagement = true;    # Enable boot entry management
  preflightChecks = true;    # Hardware compatibility checks
  sshManager = true;         # Enable SSH key management
  flakeUpdater = true;       # Enable automatic flake updates

  #
  # Security Settings
  #
  sudo = {
    requirePassword = false;  # Disable sudo password requirement
    timeout = 15;            # Sudo timeout in minutes
  };
  enableFirewall = false;    # Disable system firewall

  #
  # Localization
  #
  timeZone = "Europe/Berlin";
  locales = [ "de_US.UTF-8" ];
  keyboardLayout = "de";
  keyboardOptions = "eurosign:e";

  #
  # Profile Overrides
  #
  overrides = {
    enableSSH = null;        # Use profile default
    enableSteam = true;      # Force enable Steam
  };
}