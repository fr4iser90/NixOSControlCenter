{ config, lib, getModuleConfig, ... }:

let
  cfg = getModuleConfig "hardware";
in
{
  config = lib.mkIf (cfg.enable or false) {
    # Validation
    assertions = [
      {
        assertion = builtins.elem (cfg.cpu or "none") ["intel" "amd" "none"];
        message = "Invalid CPU configuration: ${cfg.cpu or "none"}";
      }
      {
        assertion = builtins.elem (cfg.gpu or "none") ["nvidia" "amd" "intel" "none"];
        message = "Invalid GPU configuration: ${cfg.gpu or "none"}";
      }
    ];
  };
}
