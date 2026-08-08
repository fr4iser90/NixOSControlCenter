# Per-User Config Template
# Place this file at: systemConfig/users/<username>/config.nix
#
# This config supports ALL NixOS options — not just user packages.
# It overrides/extends the central user config from systemConfig/core/base/user/config.nix.
#
# Example:
#   systemConfig/users/fr4iser/config.nix
#
# The username is derived from the parent directory name.
# Only the content after users/ is used — so this file merges into systemConfig.users.<username>.

{
  # === User Packages (per-user, not global) ===
  # These are installed via NixOS users.users.<name>.packages
  #
  # userPackages = [ "vscode" "firefox" "discord" ];

  # Prefer userPackages above. Do not use environment.systemPackages here
  # (that name is global in NixOS; NCC historically mapped it to user packages).

  # === Home Manager Config (optional) ===
  # Per-user home-manager overrides
  # home = {
  #   stateVersion = "25.11";
  # };
  # programs = {
  #   git = {
  #     userName = "Your Name";
  #     userEmail = "you@example.com";
  #   };
  # };

  # === System Overrides (per-user) ===
  # These allow per-user system-level overrides
  # networking = {
  #   interfaces.eth1 = { ... };
  # };
  # services = {
  #   openssh = {
  #     enable = true;
  #     ports = [ 2222 ];
  #   };
  # };
  # security = {
  #   pam = { ... };
  # };

  # === Session Variables (per-user) ===
  # environment.sessionVariables = {
  #   MY_VAR = "value";
  # };
}
