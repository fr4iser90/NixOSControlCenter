{
  # System-Typ (bestimmt das Profil)
  systemType = "gaming-workstation";  # server, gaming, desktop, workstation, nas, mediaserver, gaming-workstation, hybrid-gaming-server
  bootloader = "systemd-boot";
  
  # Benutzer-Grundeinstellungen
  mainUser = "fr4iser";
  guestUser = "";
  hostName = "Gaming";
  
  # Lokalisierung
  timeZone = "Europe/Berlin";
  locales = [ "en_US.UTF-8" ];
  keyboardLayout = "de";
  keyboardOptions = "eurosign:e";
  
  # Desktop (nur für Desktop-basierte Profile)
  desktop = "plasma";      # plasma, gnome, xfce
  displayManager = "sddm"; # sddm, gdm, lightdm
  session = "plasmawayland";
  autoLogin = true;
  darkMode = true;

  # Hardware
  gpu = "amdgpu";         # amdgpu, nvidia, intel
  audio = "pipewire";     # pipewire, pulseaudio
  
  # Sicherheit
  sudo = {
    requirePassword = false;
    timeout = 15;
  };

  # Shell
  defaultShell = "zsh";
  
  # Optionale Überschreibungen der Profil-Defaults
  overrides = {
    # Nur setzen wenn vom Profil-Default abgewichen werden soll
    enableSSH = null;        # null = use profile default
    enableSteam = true;      # true = override profile default
    enableFirewall = false;  # false = override profile default
  };
}
