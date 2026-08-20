{ config, lib, getModuleConfig, moduleName, ... }:

let
  cfg = getModuleConfig moduleName;
  validCpus = [
    "intel"
    "intel-core"
    "intel-xeon"
    "amd"
    "amd-ryzen"
    "amd-epyc"
    "vm-cpu"
    "none"
  ];
  validGpus = [
    "nvidia"
    "amd"
    "intel"
    "nvidia-intel"
    "nvidia-amd"
    "intel-igpu"
    "nvidia-sli"
    "amd-crossfire"
    "nvidia-optimus"
    "vm-gpu"
    "amd-intel"
    "qxl-virtual"
    "virtio-virtual"
    "basic-virtual"
    "amd-amd"
    "jetson"
    "none"
  ];
in
{
  config = lib.mkIf (cfg.enable or false) {
    assertions = [
      {
        assertion = builtins.elem (cfg.cpu or "none") validCpus;
        message = "Invalid CPU configuration: ${cfg.cpu or "none"}";
      }
      {
        assertion = builtins.elem (cfg.gpu or "none") validGpus;
        message = "Invalid GPU configuration: ${cfg.gpu or "none"}";
      }
      {
        assertion = (cfg.gpu or "none") != "jetson" || (cfg.jetpack.som or "") != "";
        message = "gpu = \"jetson\" requires hardware.jetpack.som";
      }
    ];
  };
}
