{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.chronicle.security.sandbox;
in
{
  options.services.chronicle.security.sandbox = {
    enable = mkEnableOption "sandboxing for step recorder";

    backend = mkOption {
      type = types.enum [ "bubblewrap" "firejail" ];
      default = "bubblewrap";
      description = "Sandboxing backend to use";
    };

    restrictedPaths = mkOption {
      type = types.listOf types.path;
      default = [
        "/home"
        "/tmp"
      ];
      description = "Paths accessible inside sandbox";
    };

    networkIsolation = mkOption {
      type = types.bool;
      default = false;
      description = "Isolate network access";
    };

    dropCapabilities = mkOption {
      type = types.listOf types.str;
      default = [
        "CAP_SYS_ADMIN"
        "CAP_SYS_BOOT"
        "CAP_SYS_MODULE"
      ];
      description = "Linux capabilities to drop";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      bubblewrap
      (pkgs.writeShellScriptBin "chronicle-sandbox-run" ''
      #!/usr/bin/env bash
      set -euo pipefail

      # Sandboxed execution
      COMMAND="$@"
      BACKEND="${cfg.backend}"

      run_with_bubblewrap() {
          local bind_paths="${concatStringsSep " " (map (p: "--bind ${p} ${p}") cfg.restrictedPaths)}"
          local network_flag="${if cfg.networkIsolation then "--unshare-net" else ""}"
          local caps="${concatStringsSep " " (map (c: "--cap-drop ${c}") cfg.dropCapabilities)}"
          
          ${pkgs.bubblewrap}/bin/bwrap \
              --ro-bind /nix /nix \
              --ro-bind /etc /etc \
              --dev /dev \
              --proc /proc \
              $bind_paths \
              $network_flag \
              --tmpfs /run \
              --tmpfs /var \
              --unshare-pid \
              --unshare-uts \
              --die-with-parent \
              $COMMAND
      }

      run_with_firejail() {
          ${pkgs.firejail}/bin/firejail \
              --noprofile \
              ${if cfg.networkIsolation then "--net=none" else ""} \
              --private-dev \
              --private-tmp \
              $COMMAND
      }

      case "$BACKEND" in
          bubblewrap)
              run_with_bubblewrap
              ;;
          firejail)
              run_with_firejail
              ;;
          *)
              echo "Error: Unknown backend: $BACKEND" >&2
              exit 1
              ;;
      esac
      '')
    ] ++ optionals (cfg.backend == "firejail") [
      firejail
    ];
  };
}
