{ config, lib, pkgs, getModuleConfig, moduleName, ... }:
let
  cfg = getModuleConfig moduleName;
in
{
  config = lib.mkIf (cfg.enable or false) {
    # NCC aktiviert automatisch seine Submodules wenn NCC.enable = true
    # Das macht NCC zu einem echten "Control Center" - alles oder nichts

    # Cli-Formatter ist immer aktiv (wird von anderen Modulen verwendet)
    # Cli-Registry ist immer aktiv (wird von anderen Modulen verwendet)
    # Cli-Permissions wird später hinzugefügt

    # NCC specific configuration logic
    # This module primarily acts as a container and API provider
    # for its submodules (cli-formatter, cli-registry, cli-permissions).
  };
}
