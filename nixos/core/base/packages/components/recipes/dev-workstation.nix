# Deprecated: use preset "dev-lean" (and add game-engines / python-dev as needed).
{
  description = "Full development workstation (legacy — prefer dev-lean)";
  systemTypes = [ "desktop" ];
  scope = "system";
  modules = [
    "web-dev"
    "python-dev"
    "game-engines"
    "system-dev"
  ];
}
