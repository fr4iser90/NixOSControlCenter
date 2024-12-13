
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
  hostName = "testhost";
  keyboardLayout = "de";
  keyboardOptions = "eurosign:e";
  locales = [ "en_US.UTF-8" ];
  mainUser = "testuser";
  overrides = {
  enableDevelopmentTools = true;
  enableDocker = true;
  enableVirtualization = true;
};
  session = "plasmawayland";
  sudo = {
  requirePassword = true;
  timeout = "15";
};
  systemType = "gaming-workstation";
  testing = true;
  timeZone = "Europe/Berlin";
  users = {
  testuser = {
  autoLogin = false;
  defaultShell = "zsh";
  role = "admin";
};
};
}
