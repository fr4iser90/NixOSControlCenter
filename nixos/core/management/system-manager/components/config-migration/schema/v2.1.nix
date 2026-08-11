{ lib, ... }:

{
  description = "v2.1 — system.platform required (live arch, synced like CPU/GPU)";

  requiredFields = [
    "configVersion"
  ];

  optionalFields = [
    "layout" # "monolith" | "split"
  ];

  hasConfigsDir = true;
  hasConfigVersion = true;
  hasMonolithFile = true;

  layouts = [ "monolith" "split" ];
  defaultLayout = "monolith";

  monolithFile = "systemConfig.nix";

  expectedConfigFiles = [
    "core/base/desktop/config.nix"
    "core/base/hardware/config.nix"
    "core/base/packages/config.nix"
    "core/base/localization/config.nix"
    "core/base/network/config.nix"
    "core/base/user/config.nix"
    "core/management/system-manager/config.nix"
  ];

  # Documented SSOT for flake host platform (written under system-manager leaf)
  expectedSystemManagerFields = [
    "system.platform" # x86_64-linux | aarch64-linux — from uname / preflight
  ];

  structure = {
    forbiddenAlongsideMonolith = [];
  };

  detectionPatterns = [
    "layout = \"monolith\""
    "layout = \"split\""
    "configVersion = \"2.1\""
    "system.platform"
    "platform = \"x86_64-linux\""
    "platform = \"aarch64-linux\""
  ];
}
