# Runtime paths for hyprland rice collections (not in git — fetched on install).
{
  stateRoot = "/var/lib/ncc/hyprland";
  collectionsRoot = "/var/lib/ncc/hyprland/collections";
  activeManifest = "/var/lib/ncc/hyprland/active.json";
  hyprConfigDest = "/etc/xdg/hypr/hyprland.conf";
  hyprConfigCandidates = [
    "hypr/hyprland.conf"
    ".config/hypr/hyprland.conf"
    "config/hypr/hyprland.conf"
    "hyprland.conf"
  ];
}
