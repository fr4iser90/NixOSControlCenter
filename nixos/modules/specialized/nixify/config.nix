{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, buildGoApplication ? null, gomod2nix ? null, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;

  # Nix SSOT for mapping DBs (under ./data/*.nix) — JSON only materialised for Go embed at build time
  mappingDb = import ./data/mapping-database.nix;
  programsDb = import ./data/programs-database.nix;
  gamesDb = import ./data/games-database.nix;

  mappingJson = pkgs.writeText "mapping-database.json" (builtins.toJSON mappingDb);
  programsJson = pkgs.writeText "programs-database.json" (builtins.toJSON programsDb);
  gamesJson = pkgs.writeText "games-database.json" (builtins.toJSON gamesDb);

  # Go src: module tree + generated DBs (no committed .json under static/data)
  apiSrc = pkgs.runCommand "nixify-api-src" { } ''
    cp -a ${./web-service/api}/. $out/
    chmod -R u+w $out
    mkdir -p $out/static/data
    cp ${mappingJson} $out/static/data/mapping-database.json
    cp ${programsJson} $out/static/data/programs-database.json
    cp ${gamesJson} $out/static/data/games-database.json
  '';

  snapshotScripts = {
    windows = pkgs.writeScriptBin "nixify-scan" (builtins.readFile ./snapshot/windows/nixify-scan.ps1);

    macos = pkgs.writeScriptBin "nixify-scan" ''
      #!${pkgs.bash}/bin/bash
      ${builtins.readFile ./snapshot/macos/nixify-scan.sh}
    '';

    linux = pkgs.writeScriptBin "nixify-scan" ''
      #!${pkgs.bash}/bin/bash
      ${builtins.readFile ./snapshot/linux/nixify-scan.sh}
    '';
  };

  webService = if buildGoApplication != null && gomod2nix != null then
    (buildGoApplication {
      pname = "nixify-service";
      version = "0.1.0";
      src = apiSrc;
      go = pkgs.go;
      modules = ./web-service/api/gomod2nix.toml;
      subPackages = [ "." ];
    })
  else
    pkgs.writeScriptBin "nixify-service" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail
      PORT="''${PORT:-${toString (cfg.webService.port or 8080)}}"
      HOST="''${HOST:-${cfg.webService.host or "127.0.0.1"}}"
      echo "Nixify Web Service (Placeholder) on http://$HOST:$PORT"
      echo "Mapping DB is Nix SSOT under modules/specialized/nixify/data/"
      while true; do sleep 3600; done
    '';
in
{
  config = lib.mkIf cfg.enable {
    systemd.services.nixify-service = lib.mkIf (cfg.webService.enable or false) {
      enable = true;
      description = "Nixify Web Service";
      documentation = [ "https://github.com/fr4iser90/NixOSControlCenter" ];

      after = [ "network.target" ];
      wants = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${webService}/bin/nixify-web-service";
        Restart = "on-failure";
        RestartSec = 10;

        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";

        ReadWritePaths = lib.optionals (cfg.isoBuilder.enable or false) [ (cfg.isoBuilder.outputDir or "/var/lib/nixify/isos") ];
      };

      environment = {
        PORT = toString (cfg.webService.port or 8080);
        HOST = (cfg.webService.host or "127.0.0.1");
        DATA_DIR = "/var/lib/nixify";
        # No MAPPING_DB_PATH — service uses embedded DB from Nix-generated build inputs
        SHOW_STATUS_BADGE = if (cfg.webService.showStatusBadge or true) then "true" else "false";
      };

      wantedBy = lib.mkIf (cfg.webService.autoStart or false) [ "multi-user.target" ];
    };

    environment.systemPackages = lib.mkIf (cfg.snapshot.enable or true) [
      snapshotScripts.windows
      snapshotScripts.macos
      snapshotScripts.linux
    ];

    systemd.tmpfiles.rules = [
      "d /var/lib/nixify 0755 root root -"
    ] ++ lib.optionals (cfg.isoBuilder.enable or false) [
      "d ${cfg.isoBuilder.outputDir or "/var/lib/nixify/isos"} 0755 root root -"
    ];
  };
}
