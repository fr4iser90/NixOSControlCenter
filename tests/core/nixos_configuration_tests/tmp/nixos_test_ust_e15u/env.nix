
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
  hostName = "test-7695";
  keyboardLayout = "es";
  keyboardOptions = "eurosign:e";
  locales = [ "fr_FR.UTF-8" ];
  mainUser = "testuser";
  overrides = {
  enableDevelopmentTools = false;
  enableDocker = true;
  enableSystemdBootloader = true;
  enableVirtualization = false;
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
