{ config, lib, pkgs, ... }:

let
  env = import ../../env.nix;
  types = import ./types;
  
  # Helper-Funktion zum Entfernen von null-Werten
  removeNulls = lib.filterAttrs (_: v: v != null);
  
  # Bestimme Profil-Kategorie
  profileCategory = 
    if builtins.hasAttr env.systemType types.systemTypes.desktop then "desktop"
    else if builtins.hasAttr env.systemType types.systemTypes.server then "server"
    else if builtins.hasAttr env.systemType types.systemTypes.hybrid then "hybrid"
    else throw "Unknown profile category for ${env.systemType}";
    
  # Lade das entsprechende Profil
  profile = types.systemTypes.${profileCategory}.${env.systemType} or
    (throw "Invalid system type: ${env.systemType}");
    
  # Kombiniere Profil-Defaults mit Überschreibungen
  finalConfig = lib.recursiveUpdate 
    profile.defaults
    (removeNulls (env.overrides or {}));
    
in {
  # Lade Desktop-Module wenn nötig
  imports = if finalConfig.desktop or false 
    then [ ../desktop ../sound/index.nix ]
    else [];

  # Globale Einstellungen
  nixpkgs.config.allowUnfree = true;
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';
}