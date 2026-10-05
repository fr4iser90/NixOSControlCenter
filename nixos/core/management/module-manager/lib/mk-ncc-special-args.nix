# specialArgs that NCC modules expect (systemConfig, getModuleConfig, …).
# Pass as nixosSystem.specialArgs when importing nixosModules from this flake.
#
#   specialArgs = inputs.ncc.lib.mkNccSpecialArgs {
#     inherit (pkgs) lib;
#     systemConfig = { modules.specialized.ncc-assistant.enable = true; };
#   };
{ lib, systemConfig }:
let
  discoveryLib = import ./discovery.nix;
  moduleConfigLib = import ./module-config.nix;
  discovery = discoveryLib { inherit lib; };
  moduleConfig = moduleConfigLib { inherit lib systemConfig; };
in
{
  inherit systemConfig discovery moduleConfig;
  inherit (moduleConfig)
    getModuleConfig
    getModuleMetadata
    getCurrentModuleMetadata
    getModuleApi;
}
