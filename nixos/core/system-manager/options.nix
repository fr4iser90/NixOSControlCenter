{ lib, ... }:

{
  options.core.system-manager = {
    # Version-Info ist immer verfügbar (Core)
    enableVersionChecker = lib.mkOption {
      type = lib.types.bool;
      default = true;  # Immer an
      description = "Enable version checking (always available in Core)";
    };
    
    # Deprecation-Warnungen sind immer verfügbar (Core)
    enableDeprecationWarnings = lib.mkOption {
      type = lib.types.bool;
      default = true;  # Immer an
      description = "Enable deprecation warnings (e.g., NixOS version deprecation)";
    };
    
    # Update-Funktionalität ist optional
    enableUpdates = lib.mkOption {
      type = lib.types.bool;
      default = false;  # Optional
      description = "Enable automatic updates (optional)";
    };
    
    # Auto-build nach Updates
    auto-build = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Automatically build after updates";
    };
  };
}

