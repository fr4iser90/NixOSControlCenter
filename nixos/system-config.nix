{
  # System-Typ (bestimmt das Profil)
  systemType = "gaming-workstation";
  bootloader = "systemd-boot";
  
  # Nix-Konfiguration
  allowUnfree = true;
  # Experimental Features
  entryManagement = true;
  preflightChecks = true;
  sshManager = true;
  flakeUpdater = true; # true or false auto maybe coming?

  # Benutzer-Konfiguration
  users = {
    "test" = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = true;
    };
  };

  # System-Einstellungen
  hostName = "Gaming";
  
  # Lokalisierung
  timeZone = "Europe/Berlin";
  locales = [ "de_DE.UTF-8" ];
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
  audio = "pipewire";
  
  # Sicherheit
  sudo = {
    requirePassword = false;
    timeout = 15;
  };
  enableFirewall = false;
  
  # Optionale Überschreibungen der Profil-Defaults
  overrides = {
    enableSSH = null;
    enableSteam = true;
  };
}
