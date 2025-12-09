{
  # Module Manager Configuration
  # This is a core module that dynamically discovers all available NixOS modules
  # No user configuration needed - everything works automatically

  core = {
    management = {
    module-manager = {
      # Core module - always active, no enable option
      # This module provides the 'ncc module-manager' command for toggling modules
      };
    };
  };
}
