{ config, lib, pkgs, systemConfig, ... }:

let
  # CLI formatter API
  ui = {}; # Temporarily disable UI

  # Import scripts from scripts/ directory
  postbuildScript = import ./scripts/postbuild-checks.nix { inherit config lib pkgs systemConfig; };
  prebuildCheckScript = import ./scripts/prebuild-checks.nix { inherit config lib pkgs systemConfig; };

  # Postbuild checks config
  postbuildCfg = {};

  # Prebuild checks config
  prebuildCfg = {};
in
{
  imports = [
    ./prebuild/checks/hardware/utils.nix
    ./prebuild/checks/hardware/gpu.nix
    ./prebuild/checks/hardware/cpu.nix
    ./prebuild/checks/hardware/memory.nix
    ./prebuild/checks/system/users.nix
  ];

  # Module implementation
  environment.systemPackages = with pkgs; [
    pciutils
    usbutils
    lshw
    prebuildCheckScript
  ] ++ lib.optional (postbuildCfg.enable or true) postbuildScript;

  # Postbuild activation script
  system.activationScripts.postbuildChecks = lib.mkIf (postbuildCfg.enable or true) {
    deps = [ "users" "groups" ];
    text = ''
      echo "Running postbuild checks..."
      ${postbuildScript}/bin/nixos-postbuild
    '';
  };
}