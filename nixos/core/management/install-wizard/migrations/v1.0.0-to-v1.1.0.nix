# Install-wizard v1.0.0 → v1.1.0
# Feature catalog moved to packages API (installerFeaturesBash).
# Paths are relative to this module root (parent of migrations/).
{ lib }:

{
  id = "install-wizard-1.0.0-to-1.1.0";
  from = "1.0.0";
  to = "1.1.0";
  description = "Drop stale feature-catalog generator and legacy scripts/checks";
  removeRelativePaths = [
    "scripts/ui/prompts/gen-features-from-metadata.nix"
    "scripts/checks"
  ];
}
