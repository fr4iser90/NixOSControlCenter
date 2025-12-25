{ config, pkgs, lib, ... }:

{
  # Deaktivieren von PulseAudio, falls nur ALSA verwendet werden soll
  services.pulseaudio.enable = false;

  # Aktivieren der ALSA-Dienste
  hardware.alsa = {
    enable = true;
    support32Bit = true; # Aktivieren der Unterstützung für 32-Bit-Anwendungen (falls benötigt)
  };

  # Hinzufügen von ALSA-Utilities zu den Systempaketen
  environment.systemPackages = with pkgs; [
    alsa-utils
    alsa-tools
    alsa-plugins
  ];

  # Optional: Udev-Regeln für Audio-Geräte
  services.udev.packages = [ pkgs.alsa-utils ];

}
