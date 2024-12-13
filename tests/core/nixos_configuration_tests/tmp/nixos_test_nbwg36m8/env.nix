
# This file is generated for testing
{
  allowUnfree = true;
  audio = "pipewire";
  bootloader = "systemd-boot";
  darkMode = false;
  desktop = "plasma";
  displayManager = "sddm";
  enableFirewall = true;
  gpu = "nvidia";
  hostName = "test-1654";
  keyboardLayout = "de";
  keyboardOptions = "eurosign:e";
  locales = [ "en_US.UTF-8" ];
  mainUser = "testuser";
  overrides = {
  enableFirewall = false;
  enableGameMode = true;
  enablePrinting = false;
  enableSteam = false;
  enableSystemdBootloader = true;
  enableVirtualization = true;
};
  session = "plasmawayland";
  sudo = {
  requirePassword = true;
  timeout = "15";
};
  systemType = "gaming";
  testing = true;
  timeZone = "Europe/London";
  users = {
  testuser = {
  autoLogin = false;
  defaultShell = "zsh";
  role = "admin";
};
};
}
