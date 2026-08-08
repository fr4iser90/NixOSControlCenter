{
  description = "Lean development (web-dev + system-dev)";
  systemTypes = [ "desktop" "server" ];
  scope = "system";
  modules = [
    "web-dev"
    "system-dev"
  ];
}
