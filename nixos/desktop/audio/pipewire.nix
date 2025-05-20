# /etc/nixos/modules/sound/pipewire.nix

{ config, pkgs, ... }:

{
  # Stelle sicher, dass PulseAudio deaktiviert ist, weil wir PipeWire verwenden
#  services.pulseaudio.enable = false;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
#    alsa.enable = true;
#    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;

    # Low-latency configuration for PipeWire:
    # These settings reduce audio latency (delay), which is useful for music production or gaming.
    # WARNING: Values that are too low can cause instability or audio glitches on weaker hardware.
    # If your system is stable and you don't need low latency, you can remove or comment out this block.
    extraConfig.pipewire."92-low-latency" = {
      context.properties = {
        default.clock.rate = 48000;   # Sets the audio sample rate to 48 kHz (standard for modern audio hardware)
        default.clock.quantum = 32;   # Sets the block size (samples per processing step) to 32 for low latency
      };
    };
  };

  environment.systemPackages = with pkgs; [
#    pipewire
    pavucontrol  # PulseAudio Volume Control
    alsa-utils   # ALSA Utilities
    qpwgraph     # Graphisches Frontend für PipeWire
    mda_lv2      # LADSPA-Plugins
    calf         # Weitere Audio-Plugins
  ];
}