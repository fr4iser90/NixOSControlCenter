{
  # System-Typ (bestimmt das Profil)
  systemType = "gaming-workstation";
  bootloader = "systemd-boot";
  
  # Nix-Konfiguration
  allowUnfree = true;
  # Experimental Features
  entryManagement = true;
  preflightChecks = true;   # Checks for hardware compatibility ( CPU, GPU, )
  sshManager = true;
  flakeUpdater = true; # true or false 

  # Benutzer-Konfiguration
  users = {
    "test" = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = true;
    };
    "test2" = {
      role = "restricted-admin";
      defaultShell = "zsh";
      autoLogin = false;
    };
    "test3" = {
      role = "guest";
      defaultShell = "zsh";
      autoLogin = false;
    };
  };

  # System-Einstellungen
  hostName = "Gaming";
  
  # Lokalisierung
  timeZone = "Europe/Berlin";
  locales = [ "en_US.UTF-8" ];
  keyboardLayout = "de";
  keyboardOptions = "eurosign:e";
  
  # Desktop (nur für Desktop-basierte Profile)
  desktop = "plasma";
  displayManager = "sddm";
  displayServer = "wayland"; # oder "x11" oder "hybrid"
  session = "plasma";
  darkMode = true;

  # Hardware
  gpu = "amd";
  cpu = "amd";
  audio = "pipewire";
  
  # Sicherheit
  sudo = {
    requirePassword = false;
    timeout = 15;
  };
  enableFirewall = false;
  
  # Build-LogLevel
  buildLogLevel = "minimal"; # detailed, standard, minimal, full

  # Optionale Überschreibungen der Profil-Defaults
  overrides = {
    enableSSH = null;
    enableSteam = true;
  };
}
