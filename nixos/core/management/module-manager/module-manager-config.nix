{
  # Module Manager Configuration
  # Central configuration for all NixOS modules (Core + Features)
  # Use 'ncc module-manager' to toggle modules on/off

  # Core modules (always available, some may be toggleable)
  core = {
    system = {
      audio.enable = true;
      desktop.enable = true;
      hardware.enable = true;
      network.enable = true;
      user.enable = true;
    };
    management = {
      logging.enable = true;
      checks.enable = true;
      cli-formatter.enable = true;
      command-center.enable = true;
      module-manager.enable = true;  # This module itself
    };
    infrastructure = {
      cli-formatter.enable = true;
    };
  };

  # Feature modules (opt-in, disabled by default)
  modules = {
    infrastructure = {
      homelab-manager.enable = false;
      vm-manager.enable = false;
    };
    security = {
      ssh-client-manager.enable = true;  # Enabled for testing
      ssh-server-manager.enable = false;
      lock-manager.enable = false;
    };
    specialized = {
      ai-workspace.enable = false;
      hackathon.enable = false;
    };
  };
}
