{
  #
  # Homelab Server — install-base (preset path; no legacy setup_homelab)
  # Server + stack-manager + typical package modules
  #
  systemType = "server";
  hostName = null;

  system = {
    channel = "stable";
    bootloader = "systemd-boot";
  };

  packageModules = [ "docker" "database" "web-server" ];

  users = {};

  desktop = {
    enable = false;
    environment = null;
    display = {
      manager = null;
      server = null;
      session = null;
    };
    theme = {
      dark = null;
    };
    audio = null;
  };

  hardware = {
    cpu = null;
    gpu = null;
  };

  allowUnfree = true;
  buildLogLevel = "minimal";

  features = {
    system-logger = true;
    system-checks = true;
    system-updater = true;
    ssh-manager = true;
    bootentry-manager = false;
    stack-manager = true;
    vm-manager = false;
    ai-workspace = false;
  };

  timeZone = "Europe/Berlin";
  locales = [ "en_US.UTF-8" ];
  keyboardLayout = "de";
  keyboardOptions = "terminate";

  overrides = {
    enableSSH = true;
  };

  email = "example@example.com";
  domain = "example.com";

  stackManager = {
    profiles = [ "homelab-core" ];
    swarm = null;
  };
}
