# src/nixos/modules/sound/pulseaudio.nix
{ config, pkgs, ... }:

{
  
  # PulseAudio-Konfiguration
  hardware.pulseaudio = {
    enable = true;
    support32Bit = true;
    package = pkgs.pulseaudioFull;
    # Optionale Module und Konfiguration
    extraConfig = ''
      # Bessere Latenz/Qualität
      default-fragments = 5
      default-fragment-size-msec = 2
    '';
  };

  # Explizit Pipewire deaktivieren
  services.pipewire.enable = false;

  # ALSA-Plugins für PulseAudio
  nixpkgs.config.pulseaudio = true;

  # Benutzer zur audio-Gruppe hinzufügen wird in users.nix gehandhabt
  # durch die roleGroups-Definition
}