{ config, lib, pkgs, ... }:

{
  # Basis CPU-Einstellungen für VMs
  boot = {
    kernelModules = [ "kvm-intel" "kvm-amd" ];  # Unterstützung für beide CPU-Typen
    kernelParams = [
      "processor.max_cstate=1"  # Reduziert CPU-Latenz in VMs
      "idle=poll"              # Verhindert CPU-Sleep-States
    ];
  };

  # CPU-spezifische Einstellungen für VMs
  hardware.cpu = {
    amd.updateMicrocode = false;    # Keine Microcode-Updates in VMs nötig
    intel.updateMicrocode = false;
  };
}