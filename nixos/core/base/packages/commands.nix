{ config, lib, pkgs, getModuleApi, systemConfig ? null, ... }:
let
  cfg = lib.attrByPath ["core" "base" "packages"] {} systemConfig;
  cliRegistry = getModuleApi "cli-registry";

  packagesCli = import ./scripts/ncc-packages.nix { inherit pkgs; };
in
{
  config = lib.mkIf (cfg.enable or true)
    (cliRegistry.registerCommandsFor "packages" [
      {
        name = "packages";
        domain = "packages";
        description = "Package management CLI";
        category = "base";
        script = "${packagesCli}/bin/ncc-packages";
        arguments = [];
        type = "manager";
        shortHelp = "packages - Package Management CLI";
        longHelp = ''
          Add, remove, and list packages for users and the system.

          Usage:
            ncc packages add <package> [--user <name>] [--system]
            ncc packages remove <package> [--user <name>] [--system]
            ncc packages list [--system]

          Defaults:
            - Without flags, operations target the current user's userPackages
            - --system targets systemPackages (global, all users)
            - --user <name> overrides the target user

          Examples:
            ncc packages add vscode                  # Add to current user
            ncc packages add nginx --system          # Add to system
            ncc packages add firefox --user alice    # Add to alice
            ncc packages list
        '';
      }
    ]);
}
