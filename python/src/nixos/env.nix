{
  # System-Typ (bestimmt das Profil)
  systemType = "gaming-workstation";
  bootloader = "systemd-boot";
  
  # Nix-Konfiguration
  allowUnfree = true;
  # Experimental Features
  entryManagement = true;
  
  # Benutzer-Konfiguration
  users = {
    "fr4iser" = {
      role = "admin";
      defaultShell = "zsh";
      autoLogin = true;
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
  session = "plasma";
  darkMode = true;

  # Hardware
  gpu = "amdgpu";
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
