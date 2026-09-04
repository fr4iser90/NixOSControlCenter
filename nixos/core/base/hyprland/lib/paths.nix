# Runtime paths for hyprland rice collections (not in git — fetched on install).
{
  stateRoot = "/var/lib/ncc/hyprland";
  collectionsRoot = "/var/lib/ncc/hyprland/collections";
  activeManifest = "/var/lib/ncc/hyprland/active.json";
  hyprConfigDest = "/etc/xdg/hypr/hyprland.conf";
  hyprConfigDestLua = "/etc/xdg/hypr/hyprland.lua";
  hyprConfigCandidates = [
    "hypr/hyprland.conf"
    ".config/hypr/hyprland.conf"
    "config/hypr/hyprland.conf"
    "hyprland.conf"
    "dots/hyprland.conf"
    "dots/.config/hypr/hyprland.conf"
    "dots/.config/hypr/hyprland.lua"
    "hypr/hyprland.lua"
    ".config/hypr/hyprland.lua"
    "config/hypr/hyprland.lua"
    "compositors/hyprland/hyprland.lua"
    "compositors/hyprland/hyprland.conf"
  ];
}
