{ lib, colors, config, ... }:

{
  messages = import ./messages.nix { inherit lib colors; };
  badges = import ./badges.nix { inherit lib colors; };
}