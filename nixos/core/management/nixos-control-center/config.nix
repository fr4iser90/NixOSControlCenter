{ config, lib, pkgs, getModuleConfig, moduleName, ... }:
let
  cfg = getModuleConfig moduleName;
in
{
  config = {
    # NCC is always active (Core module, no enable option)
    # NCC aktiviert automatisch seine Submodules
    # Das macht NCC zu einem echten "Control Center" - alles oder nichts

    # Cli-Formatter ist immer aktiv (wird von anderen Modulen verwendet)
    # Cli-Registry ist immer aktiv (wird von anderen Modulen verwendet)
    # Cli-Permissions wird später hinzugefügt

    # NCC specific configuration logic
    # This module primarily acts as a container and API provider
    # for its submodules (cli-formatter, cli-registry, cli-permissions).
  };
}
