{ config, lib, pkgs, ... }:

{
  # Basis CPU-Einstellungen
  boot = {
    # Grundlegende CPU-Unterstützung
    kernelModules = [ "kvm" ];  # Basis KVM-Support
    
    # Conservative CPU-Parameter
    kernelParams = [
      "processor.max_cstate=1"     # Standard C-State
      "intel_pstate=passive"       # Passives Power-Management
      "amd_pstate=passive"         # Für beide CPU-Typen
    ];
  };
}