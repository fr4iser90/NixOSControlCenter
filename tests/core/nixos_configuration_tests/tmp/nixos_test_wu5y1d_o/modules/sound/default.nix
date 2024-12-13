# src/nixos/modules/sound/default.nix
{ config, pkgs, ... }:

let
  env = import ../../env.nix;
in
if env.audio == "pipewire" then import ./pipewire.nix { inherit config pkgs; }
else if env.audio == "pulseaudio" then import ./pulseaudio.nix { inherit config pkgs; }
else if env.audio == "alsa" then import ./alsa.nix { inherit config pkgs; }
else {}  # Kein Audio-System wenn nicht spezifiziert