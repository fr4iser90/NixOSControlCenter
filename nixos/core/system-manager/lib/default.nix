# Library exports for system-manager
# Note: homelab-utils.nix has been moved to features/homelab-manager/lib/

rec {
  # Config management helpers (for all modules)
  config-helpers = import ./config-helpers.nix;
}

