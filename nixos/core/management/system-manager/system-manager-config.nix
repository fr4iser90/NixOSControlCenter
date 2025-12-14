{
  # Core system configuration
  configVersion = "1.0";
  systemType = "desktop";
  system = {
    channel = "stable";
  };
  features = {
    system-logger = true;
    system-checks = true;
    system-config-manager = false;
    system-discovery = false;
    ssh-client-manager = false;
    ssh-server-manager = false;
    bootentry-manager = false;
    homelab-manager = false;
    vm-manager = false;
    ai-workspace = false;
  };
}
