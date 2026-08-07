{ lib, ... }:

let
  inherit (lib) mkOption mkEnableOption types;

  mcpServerModule = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable this MCP server";
      };
      transport = mkOption {
        type = types.enum [ "stdio" "sse" "http" ];
        default = "stdio";
        description = "MCP transport type";
      };
      command = mkOption {
        type = types.str;
        description = "Command to run for stdio transport";
      };
      args = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "Arguments to pass to the command";
      };
      env = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Environment variables for the MCP server";
      };
    };
  };

  scheduleModule = types.submodule {
    options = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable this scheduled job";
      };
      onCalendar = mkOption {
        type = types.str;
        example = "daily";
        description = "systemd calendar expression (e.g. daily, weekly, *-*-* 03:00:00)";
      };
      persistent = mkOption {
        type = types.bool;
        default = true;
        description = "Run missed jobs on next boot";
      };
      goal = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Natural language goal for the agent (optional if playbook is set)";
      };
      playbook = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "health-report";
        description = "Builtin/user playbook name (e.g. health-report, unused-modules-dry-run)";
      };
      kind = mkOption {
        type = types.enum [ "agent" "probe" ];
        default = "agent";
        description = ''
          agent = LLM playbook/goal.
          probe = tool-only check (e.g. disk-nix); escalate to playbook only over threshold.
        '';
      };
      probe = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "disk-nix";
        description = "Probe id when kind = probe (currently: disk-nix)";
      };
      thresholdPct = mkOption {
        type = types.nullOr types.number;
        default = 85;
        description = "For disk-nix probe: root usage %% that triggers agent escalation";
      };
      escalatePlaybook = mkOption {
        type = types.nullOr types.str;
        default = "disk-nix-gc-advisor";
        description = "Playbook to run when probe exceeds threshold";
      };
      maxSteps = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "Override agent.maxSteps for this schedule";
      };
      allowWrite = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Override agent.allowWrite for this schedule";
      };
      allowRebuild = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Override agent.allowRebuild for this schedule";
      };
      dryRun = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Override agent.dryRun for this schedule";
      };
      profile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override agent.profile for this schedule";
      };
      model = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Override model for this schedule";
      };
    };
  };

  profileModule = types.submodule {
    options = {
      hostname = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Target hostname for this profile";
      };
      flakeAttr = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Flake attribute for this profile";
      };
      endpoint = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "LLM endpoint override for this profile";
      };
      model = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Model override for this profile";
      };
    };
  };
in
{
  options.systemConfig.modules.specialized.ncc-assistant = {
    _version = mkOption {
      type = types.str;
      default = "1.0.0";
      internal = true;
      description = "Module version";
    };

    _dependencies = mkOption {
      type = types.listOf types.str;
      default = [ "cli-registry" "system-manager" ];
      internal = true;
      description = "Modules this module depends on";
    };

    _conflicts = mkOption {
      type = types.listOf types.str;
      default = [ ];
      internal = true;
      description = "Modules that conflict with this module";
    };

    enable = mkEnableOption "NCC AI Assistant (chat + MCP tools for systemConfig)";

    endpoint = mkOption {
      type = types.str;
      default = "http://localhost:11434/v1";
      example = "https://llm.example.com/v1";
      description = ''
        Base URL for an OpenAI-compatible API. Host-only URLs get /v1 appended.
        Unused when api = "anthropic".
      '';
    };

    api = mkOption {
      type = types.enum [ "openai-compatible" "anthropic" ];
      default = "openai-compatible";
      description = ''
        Wire protocol: openai-compatible (Ollama, llama.cpp, OpenAI, etc.)
        or anthropic (native Messages API).
      '';
    };

    provider = mkOption {
      type = types.nullOr (types.enum [ "openai-compatible" "anthropic" "ollama" "openai" ]);
      default = null;
      description = "Deprecated alias of api. Prefer setting api instead.";
    };

    model = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "Qwen3.6-35B-A3B";
      description = "Model id sent in chat requests. null = auto-detect from gateway.";
    };

    apiKeyFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/run/secrets/ncc-llm-api-key";
      description = "Path to API key file (sops/agenix). Usually leave null.";
    };

    apiHeaderName = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "X-API-KEY";
      description = "HTTP header for the API key. null = auto-detect.";
    };

    maxTokens = mkOption {
      type = types.nullOr types.int;
      default = null;
      description = "Optional max_tokens in requests. null = server default.";
    };

    temperature = mkOption {
      type = types.nullOr types.float;
      default = null;
      description = "Sampling temperature. null = server default.";
    };

    allowWrite = mkOption {
      type = types.bool;
      default = true;
      description = "Allow apply_module_config from built-in ncc ai chat (still requires confirm)";
    };

    mcpAllowWrite = mkOption {
      type = types.bool;
      default = false;
      description = "Allow write tools when serving MCP to external clients";
    };

    allowRebuild = mkOption {
      type = types.bool;
      default = false;
      description = "Allow apply_system tool (ncc system build switch). Requires confirm=CONFIRM";
    };

    forceDangerous = mkOption {
      type = types.bool;
      default = false;
      description = "Acknowledge dangerous configurations (e.g. scheduled rebuilds)";
    };

    # Tools configuration
    tools = {
      allowShell = mkOption {
        type = types.bool;
        default = false;
        description = "Allow shell command execution tool";
      };

      shellAllowlist = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [ "systemctl status" "journalctl" "df" ];
        description = "Shell commands allowed when allowShell is true (prefix match)";
      };

      mcpServers = mkOption {
        type = types.attrsOf mcpServerModule;
        default = { };
        example = {
          filesystem = {
            command = "npx";
            args = [ "-y" "@anthropic/mcp-filesystem" "/home" ];
          };
        };
        description = "External MCP servers the agent can connect to";
      };
    };

    # Agent configuration
    agent = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable autonomous agent mode";
      };

      maxSteps = mkOption {
        type = types.int;
        default = 24;
        description = "Maximum tool steps per agent run";
      };

      timeoutSec = mkOption {
        type = types.int;
        default = 1800;
        description = "Agent run timeout in seconds";
      };

      allowWrite = mkOption {
        type = types.bool;
        default = false;
        description = "Allow agent to write config (requires confirmation based on confirm mode)";
      };

      allowRebuild = mkOption {
        type = types.bool;
        default = false;
        description = "Allow agent to trigger system rebuilds";
      };

      confirm = mkOption {
        type = types.enum [ "always" "writes" "never" ];
        default = "writes";
        description = ''
          Confirmation mode: always (every tool), writes (only destructive),
          never (autonomous - dangerous).
        '';
      };

      dryRun = mkOption {
        type = types.bool;
        default = false;
        description = "Agent proposes changes without applying them";
      };

      profile = mkOption {
        type = types.nullOr types.str;
        default = "read-only";
        description = "Default agent profile (read-only, config-writer, ops; aliases: cautious, autonomous)";
      };

      requirePreflightBeforeRebuild = mkOption {
        type = types.bool;
        default = false;
        description = "Require preflight check before any rebuild";
      };

      notifications = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable desktop notifications for agent events";
        };

        timeoutSec = mkOption {
          type = types.int;
          default = 300;
          description = "Timeout for notification response";
        };

        onTimeout = mkOption {
          type = types.enum [ "block" "queue" "pause" ];
          default = "block";
          description = "Action when notification times out waiting for response";
        };

        notifyOnScheduleStart = mkOption {
          type = types.bool;
          default = false;
          description = "Send notification when scheduled job starts";
        };

        notifyOnJobEnd = mkOption {
          type = types.bool;
          default = true;
          description = "Send notification when job completes";
        };
      };

      tray = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable system tray icon for agent status";
        };
      };

      schedules = mkOption {
        type = types.attrsOf scheduleModule;
        default = { };
        example = {
          daily-health = {
            enable = true;
            onCalendar = "*-*-* 03:15:00";
            playbook = "health-report";
            profile = "read-only";
            dryRun = true;
            maxSteps = 15;
          };
          weekly-module-audit = {
            enable = true;
            onCalendar = "Sun *-*-* 04:00:00";
            playbook = "unused-modules-dry-run";
            profile = "read-only";
            dryRun = true;
            maxSteps = 30;
          };
        };
        description = ''
          Scheduled agent jobs (systemd timers). Prefer playbook + read-only + dryRun.
          Leave empty by default — copy examples from template-config.nix to opt in.
        '';
      };
    };

    # Multi-host profiles
    profiles = mkOption {
      type = types.attrsOf profileModule;
      default = { };
      example = {
        server = {
          hostname = "server.local";
          flakeAttr = "nixosConfigurations.server";
        };
      };
      description = "Named profiles for multi-host management";
    };
  };
}
