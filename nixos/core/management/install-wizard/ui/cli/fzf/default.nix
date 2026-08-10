# fzf / prompt UI for install-wizard.
# Bash bodies live in ../../scripts/ui/prompts/*.nix and are assembled into the
# store tree at ui/prompts/ by scripts/default.nix (template: no repo .sh).
{ pkgs }:
{
  # Entry used by installer via SCRIPT_ROOT/ui/prompts (store).
  prompts = ../.. + "/scripts/ui/prompts";
}
