{ lib, ... }:

{
  description = "Dual layout - nested monolith (systemConfig.nix) or split (systemConfig/**/config.nix)";

  requiredFields = [
    "configVersion"
  ];

  optionalFields = [
    "layout" # "monolith" | "split"
  ];

  hasConfigsDir = true; # optional when layout = monolith
  hasConfigVersion = true;
  hasMonolithFile = true;

  # Accepted layout values
  layouts = [ "monolith" "split" ];
  defaultLayout = "monolith";

  # Monolith file (sibling to systemConfig/)
  monolithFile = "systemConfig.nix";

  # Same leaf paths as v1 when layout = split
  expectedConfigFiles = [
    "core/base/desktop/config.nix"
    "core/base/hardware/config.nix"
    "core/base/packages/config.nix"
    "core/base/localization/config.nix"
    "core/base/network/config.nix"
    "core/base/user/config.nix"
    "core/management/system-manager/config.nix"
  ];

  structure = {
    # Monolith holds the full nested attrset (same shape as in-memory systemConfig)
    # Split forbids a live monolith file (convert removes it)
    forbiddenAlongsideMonolith = [];
  };

  detectionPatterns = [
    "layout = \"monolith\""
    "layout = \"split\""
    "configVersion = \"2.0\""
  ];
}
