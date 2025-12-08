{ config, lib, pkgs, ... }:

{
  imports = [
    ./api/rest
#    ./models
  ];

  # Hier könnten LLM-spezifische Konfigurationen kommen
  # z.B. gemeinsame Einstellungen für verschiedene Modelle,
  # API-Konfigurationen, etc.
}