
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
  hostName = "test-3479";
  keyboardLayout = "es";
  keyboardOptions = "eurosign:e";
  locales = [ "fr_FR.UTF-8" ];
  mainUser = "testuser";
  overrides = {
  enableDevelopmentTools = false;
  enableDiscord = false;
  enableGameMode = false;
  enableWebcam = false;
};
  session = "plasmawayland";
  sudo = {
  requirePassword = true;
  timeout = "15";
};
  systemType = "gaming";
  testing = true;
  timeZone = "America/New_York";
  users = {
  testuser = {
  autoLogin = false;
  defaultShell = "zsh";
  role = "admin";
};
};
}
