# User-scoped creative/gaming extras (not Steam — Steam stays a system set)
{
  description = "Personal creative tools (blender, gimp, krita) — current user only";
  systemTypes = [ "desktop" ];
  scope = "user";
  packages = [
    "blender"
    "gimp"
    "krita"
    "inkscape"
  ];
}
