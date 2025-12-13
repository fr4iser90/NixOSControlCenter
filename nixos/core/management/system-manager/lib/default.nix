# Library exports for system-manager
# Note: homelab-utils.nix has been moved to features/homelab-manager/lib/

rec {
  # Config management helpers (for all modules)
  config-helpers = import ../../module-manager/lib/config-helpers.nix;
  
  # Version management helpers (for module version checking)
  version-helpers = import ./version-helpers.nix;
  
  # Backup helpers (centralized backup functionality)
  backup-helpers = import ./backup-helpers.nix;
}

config-migration = import ./config-migration/default.nix;
