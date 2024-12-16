{ pkgs }:

with pkgs; [
  gtk4
  gobject-introspection
  dbus
  pkg-config
  glib
  git
  git-credential-manager
  makeWrapper
  tree
  nixos-rebuild
  nixos-container 
]
