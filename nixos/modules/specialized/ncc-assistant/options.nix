{ lib, ... }:

let
  inherit (lib) mkOption mkEnableOption types;

  # Phase 39 L8: what a run may spend per day. Null means "use the built-in default"
  # (see budgets.py) and 0 turns the counter off, so the numbers live in one place.
  budgetModule = types.submodule {
    options = {
      maxRunsPerDay = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
        example = 1;
        description = ''
          Agent runs per day (UTC) for this actor. Null keeps the built-in default of
          no limit; 0 also means no limit. A run that would exceed it is skipped before
          the LLM call — it costs nothing and the unit still exits 0.
        '';
      };
      maxPrsPerDay = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
        example = 3;
        description = ''
          Agent pull requests per repository per day. Default 3. Over budget the work
          stops at push: the branch is on the remote, the PR is held for tomorrow.
        '';
      };
      maxDiffLines = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
        example = 800;
        description = ''
          Changed lines (added plus removed) allowed in one commit, measured on what is
          already staged. Default 800. Over budget the commit is refused and unstaged,
          so the work stays local and the task stays open.
        '';
      };
      maxOpenAgentPrs = mkOption {
        type = types.nullOr types.ints.unsigned;
        default = null;
        example = 5;
        description = ''
          Agent pull requests kept open per repository. Default 5, counted locally from
          PRs this assistant opened minus the ones it merged. Over budget no new PR is
          opened until one lands or is closed.
        '';
      };
    };
  };

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
      permissions = {
        repo = mkOption {
          type = types.nullOr (types.enum [
            "observe"
            "propose"
            "commit"
            "push"
            "pr"
            "merge"
            "release"
          ]);
          default = null;
          example = "push";
          description = ''
            Repo step for this schedule (phase 39 permission ladder). Null derives the
            step from dryRun / profile / allowWrite, so existing hosts keep behaving as
            before. Only narrows the host ceiling
            ({{Option|systemConfig.aiAssistant.grants.repoCeiling}}) — it never widens it.
          '';
        };
        system = mkOption {
          type = types.nullOr (types.enum [ "none" "config-write" "rebuild" ]);
          default = null;
          example = "none";
          description = ''
            System step for this schedule. Null derives it from dryRun / allowWrite /
            allowRebuild. A schedule can never gain rights the host denies.
          '';
        };
        budget = mkOption {
          type = budgetModule;
          default = { };
          example = { maxRunsPerDay = 1; maxPrsPerDay = 3; maxDiffLines = 800; };
          description = ''
            Per-day budgets for this schedule, narrowing
            {{Option|systemConfig.aiAssistant.grants.budget}}. Each counter left null
            takes the host value; a schedule never gets more room than the host.
          '';
        };
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

    # Permission ladder (phase 39): the host is the ceiling, runs and schedules narrow.
    grants = {
      repoCeiling = mkOption {
        type = types.enum [
          "observe"
          "propose"
          "commit"
          "push"
          "pr"
          "merge"
          "release"
        ];
        default = "pr";
        description = ''
          Highest repo step any agent run on this host may reach: observe, propose,
          commit, push, pr, merge, release. The default pr is exactly what the
          workflow tools could already do, so hosts that set nothing keep behaving
          as before. Schedules and --grant may only lower this; asking for more is
          refused, not clamped. merge/release additionally need a human unless the
          grant explicitly carries them.
        '';
      };
      budget = mkOption {
        type = budgetModule;
        default = { };
        example = { maxRunsPerDay = 1; maxDiffLines = 400; };
        description = ''
          Per-day budgets for granted runs (phase 39). They bind schedules and
          {{Command|ncc ai agent run --grant …}}, not a human at the CLI: with no grant
          in play the counters are not consulted. Leave a counter null for the built-in
          default, set 0 to switch it off. Schedules may lower these, never raise them.
        '';
      };
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
        description = ''
          Shell command prefixes allowed when allowShell is true. An empty list
          denies every command: allowShell alone never runs a command.
        '';
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
        default = -1;
        description = ''
          Maximum tool steps per agent run. -1 (default) means unlimited, like
          qwen-code's model.maxSessionTurns; set a positive integer to opt in to a
          budget. Schedules and playbooks that set maxSteps keep their own value.
        '';
      };

      chatMaxRounds = mkOption {
        type = types.int;
        default = -1;
        description = ''
          Tool-call rounds per chat message (Companion / GUI chat / ncc-assistant chat).
          -1 (default) means unlimited, like qwen-code; set a positive integer to cap
          a round-hungry model.
        '';
      };

      contextWindow = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = ''
          Context window for chat in tokens. null (default) lets the assistant
          discover it from the gateway (llama.cpp /props, Ollama num_ctx,
          /models max_model_len) per endpoint+model and falls back to 8192 when
          nothing advertises one. Set a number to override a wrong or missing
          reading — that value is then used without probing.
        '';
      };

      compactThreshold = mkOption {
        type = types.int;
        default = -1;
        description = ''
          Token count at which a chat is compacted (older turns replaced by an
          LLM summary). -1 (default) derives it like qwen-code: 85 percent of
          the context window, capped at the window minus 33000 tokens (20000
          kept for the summary output plus a 13000 buffer) whenever that cap is
          positive — 6963 at an 8192 window, 167000 at 200000. A positive value
          is used as-is in tokens.
        '';
      };

      autoCompact = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Compact automatically before a request that would pass the threshold.
          false keeps the whole transcript and relies on manual compaction
          (ncc ai context compact), so an over-long prompt fails instead.
        '';
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
          description = ''
            Send a notification when a run started by a schedule unit begins (agent goal or
            disk probe). Only runs whose actor is schedule notify — an interactive session is
            already on screen.
          '';
        };

        notifyOnJobEnd = mkOption {
          type = types.bool;
          default = true;
          description = "Send notification when an agent run ends, whatever the outcome: finished, cancelled or failed";
        };
      };

      tray = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Enable system tray icon for agent status";
        };
      };

      companion = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = "Ship desktop companion (avatar + mini chat) entry / optional autostart hint";
        };
      };

      # Doomscroll: real DNS/hosts-style domain blocks (not URL-path /shorts/)
      focus = {
        hostsBlock = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              When true, listed domains are added to networking.extraHosts (0.0.0.0 / ::1),
              same idea as a Windows hosts file. Blocks whole domains — not URL paths
              like /shorts/. Timed blocks after an interrupt use ncc-focus-netblock (nft).
            '';
          };
          domains = mkOption {
            type = types.listOf types.str;
            default = [ ];
            example = [
              "www.youtube.com"
              "youtube.com"
              "m.youtube.com"
              "www.tiktok.com"
              "tiktok.com"
            ];
            description = "Domains to sinkhole via networking.extraHosts when hostsBlock.enable.";
          };
        };
      };

      harness = mkOption {
        type = types.enum [ "native" "qwen" "dsh" ];
        default = "native";
        description = ''
          Default agent/chat harness. ``native`` = NCC ChatSession + ToolRuntime.
          ``qwen`` / ``dsh`` = external coding harness (must be installed on PATH).
        '';
      };

      codingHarness = mkOption {
        type = types.enum [ "auto" "native" "qwen" "dsh" ];
        default = "auto";
        description = ''
          Harness for coding/git-tagged templates and coding-like goals.
          ``auto`` picks qwen if installed, else dsh, else falls back to ``harness``.
        '';
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
