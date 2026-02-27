{ config, lib, pkgs, getModuleApi, systemConfig ? null, ... }:
let
  cfg = lib.attrByPath ["core" "base" "packages"] {} systemConfig;
  cliRegistry = getModuleApi "cli-registry";
  packagesTui = pkgs.writeShellScriptBin "ncc-packages-tui" ''
    echo "📦 Package Manager"
    echo "TUI not available at build time. Use: ncc packages <action>"
  '';
in
{
  config = lib.mkIf (cfg.enable or true)
    (cliRegistry.registerCommandsFor "packages" [
      {
        name = "packages";
        domain = "packages";
        description = "Package manager TUI";
        category = "base";
        script = "${packagesTui}/bin/ncc-packages-tui";
        arguments = [];
        type = "manager";
        shortHelp = "packages - Package Manager (TUI)";
        longHelp = ''
          Package manager TUI placeholder.
        '';
      }
    ]);
}