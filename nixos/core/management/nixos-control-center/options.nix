{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  options.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "1.0.0";
      internal = true;
      description = "NixOS Control Center module version";
    };

    enable = lib.mkEnableOption "NixOS Control Center";

    # NCC API Option (GENERISCH unter configPath.api!)
    api = lib.mkOption {
      type = lib.types.attrs;
      internal = true;
      description = "NCC API for other modules";
    };

    # NCC-spezifische Optionen können hier hinzugefügt werden
    # theme = lib.mkOption {
    #   type = lib.types.enum [ "dark" "light" ];
    #   default = "dark";
    #   description = "Theme for NCC CLI output";
    # };
  };
}
