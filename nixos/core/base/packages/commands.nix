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
          Add, remove, and list packages, module sets, and presets.

          Single packages (nixpkgs):
            ncc packages add <package> [--user <name>] [--system]
            ncc packages remove <package> [--user <name>] [--system]
            ncc packages list [--system]

          Module sets and presets (packageModules):
            ncc packages module list                  List active packageModules
            ncc packages module available             Show all sets and presets
            ncc packages module add <name>...         Add set(s) or preset(s)
            ncc packages module remove <name>...      Remove set(s)
            ncc packages module info <name>           Show details for a set/preset

          Defaults for single packages:
            - Without flags, operations target the current user's userPackages
            - --system targets systemPackages (global, all users)
            - --user <name> overrides the target user

          Module/preset operations edit core.base.packages via config-facade
          (monolith: /etc/nixos/systemConfig.nix | split: .../packages/config.nix).
          Preset names are auto-expanded to their set list.

          Layout:
            ncc system config-layout detect
            ncc system config-layout convert --to monolith|split

          Examples:
            ncc packages add vscode                          # User package
            ncc packages add nginx --system                  # System package
            ncc packages module add gaming                   # Single set
            ncc packages module add gaming-desktop           # Apply preset
            ncc packages module add gaming streaming         # Multiple sets
            ncc packages module remove emulation             # Remove a set
            ncc packages module available                    # List everything
            ncc packages module info gaming-desktop          # Inspect preset
        '';
      }
    ]);
}
