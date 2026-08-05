# Nixify static databases (Nix SSOT — JSON only generated at Go build time into the store)
{
  mapping = import ./mapping-database.nix;
  programs = import ./programs-database.nix;
  games = import ./games-database.nix;
}
