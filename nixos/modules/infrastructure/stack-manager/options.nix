{ lib, getCurrentModuleMetadata, ... }:

let
  metadata = getCurrentModuleMetadata ./.;
  configPath = metadata.configPath;
in {
  options.systemConfig.${configPath} = {
    _version = lib.mkOption {
      type = lib.types.str;
      default = "2.0.0";
      internal = true;
      description = "Module version";
    };

    _dependencies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      internal = true;
      description = "Modules this module depends on";
    };

    _conflicts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      internal = true;
      description = "Modules that conflict with this module";
    };

    enable = lib.mkEnableOption "stack manager (homelab + compute catalog profiles)";

    swarm = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "manager" "worker" ]);
      default = null;
      description = "Docker Swarm role for homelab family; null = single-node. Compute profiles never use Swarm.";
    };

    # External catalog (Docker stacks / profiles) — default NCC-Stacks
    catalog = {
      repoUrl = lib.mkOption {
        type = lib.types.str;
        default = "https://github.com/fr4iser90/NCC-Stacks.git";
        description = "Git URL of the stack catalog repository";
      };
      ref = lib.mkOption {
        type = lib.types.str;
        default = "main";
        description = "Git branch or tag to fetch";
      };
      # Relative to virt user home after fetch (repo root contents land here)
      installRoot = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Optional install subdirectory under virt home; empty = virt home itself";
      };
    };

    profiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "homelab-core" "homelab-media" ];
      description = ''
        Catalog profiles to manage on this host (e.g. homelab-core, compute-llm-x86).
        Empty = interactive / manual via ncc stacks init.
      '';
    };

    stacks = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.anything);
      default = [];
      description = "Optional explicit stack entries (legacy / advanced); prefer profiles";
      example = [
        {
          name = "my-stack";
          compose = "/path/to/docker-compose.yml";
        }
      ];
    };

    fleetTags = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = {};
      example = {
        "admin@jetson" = [ "gpu" "arm" "compute" ];
        "admin@homelab" = [ "swarm" "edge" ];
      };
      description = ''
        Declarative operator labels for fleet hosts (SSH creds key ``user@host``).
        Merged in the Stacks GUI with cockpit tags in ~/.config/ncc/stacks-ui.json.
      '';
    };

    dns = {
      enable = lib.mkEnableOption "pre-seed Cloudflare DNS credentials for homelab gateway";

      provider = lib.mkOption {
        type = lib.types.str;
        default = "cloudflare";
        description = "DNS provider code (only cloudflare implemented in NCC adapter)";
      };

      cloudflare = {
        apiEmail = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Cloudflare API email for Traefik ACME / DDNS";
        };

        apiToken = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Cloudflare API token (sensitive — prefer cockpit dns-env for secrets)";
        };
      };
    };
  };
}
