# User Module API - Permission System Functions
{ lib }:

let
  # Capabilities basierend auf Rolle (für NCC Permission System)
  roleCapabilities = {
    admin = [
      "system.update" "system.build" "system.check.*" "module.*" "user.*" "package.*"
      "network.*" "hardware.*" "boot.*" "desktop.*" "audio.*" "localization.*"
    ];
    guest = [
      "system.check.self" "user.read.self"
    ];
    "restricted-admin" = [
      "system.update" "system.build" "system.check.*" "user.read.self" "network.read"
    ];
    virtualization = [
      "system.check.self" "user.read.self" "package.docker" "package.podman"
    ];
  };

  # Helper function to get capabilities for a role
  getCapabilitiesForRole = role: roleCapabilities.${role} or [];

  # Helper function to check if a permission matches
  hasPermission = caps: requiredPerm:
    lib.any (cap:
      # Simple wildcard matching (cap ends with .* or exact match)
      (lib.hasSuffix ".*" cap && lib.hasPrefix (lib.removeSuffix ".*" cap) requiredPerm) ||
      (cap == requiredPerm)
    ) caps;
in
{
  # Funktion um Capabilities eines Users zu bekommen (gibt Liste zurück)
  getUserCapabilities = role: getCapabilitiesForRole role;

  # Funktion um Permission zu checken
  checkUserPermission = role: requiredPerm: let
    userCaps = getCapabilitiesForRole role;
  in hasPermission userCaps requiredPerm;

  # Alle verfügbaren Rollen
  availableRoles = builtins.attrNames roleCapabilities;

  # Version der API
  version = "1.0.0";
}
