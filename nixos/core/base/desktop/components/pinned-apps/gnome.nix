{ config, lib, pkgs, getModuleConfig, ... }:

# Placeholder: GNOME favorites via dconf (org.gnome.shell favorite-apps)
# Not implemented yet — Plasma-only MVP.
{
  # When implementing:
  #   home-manager.users.<u>.dconf.settings."org/gnome/shell".favorite-apps = pins;
  #   with once-apply marker ~/.config/ncc/pinned-apps-applied (or HM immutable favorites tradeoff)
  assertions = [];
}
