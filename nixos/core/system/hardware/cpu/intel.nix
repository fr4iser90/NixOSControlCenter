{ config, lib, pkgs, ... }:

{
  hardware.cpu.intel.updateMicrocode = true;
  
  boot = {
    kernelModules = [ "kvm-intel" ];
    kernelParams = [ "intel_pstate=active" ];
  };
}