{
  enable = false;
  # OpenAI-compatible gateway (Ollama, llama.cpp, OpenWebUI, etc.)
  endpoint = "http://localhost:11434/v1";
  # Auth: leave unset - ncc ai prompts + caches in ~/.config/ncc-assistant/
  # apiKeyFile = "/run/secrets/ncc-llm-api-key";  # sops/agenix
  allowWrite = true;
  mcpAllowWrite = false;
  allowRebuild = false;

  # Tools: shell access and external MCP servers
  # tools.allowShell = false;
  # tools.shellAllowlist = [ "systemctl status" "journalctl" ];
  # tools.mcpServers = { };

  # Agent: autonomous mode settings
  # agent.enable = true;
  # agent.maxSteps = 24;
  # agent.confirm = "writes";  # always | writes | never
  # agent.dryRun = false;
  # agent.profile = "read-only";
  # agent.notifications.enable = true;
  # agent.tray.enable = false;

  # --- Recommended schedules (opt-in: uncomment to enable) ---
  # Safe defaults: playbook + read-only + dryRun. Only one agent runs at a time.
  # Staggered nights so they don't compete for LLM slots.
  #
  # agent.schedules.daily-health = {
  #   enable = true;
  #   onCalendar = "*-*-* 03:15:00";
  #   playbook = "health-report";
  #   profile = "read-only";
  #   dryRun = true;
  #   maxSteps = 15;
  # };
  #
  # agent.schedules.weekly-module-audit = {
  #   enable = true;
  #   onCalendar = "Sun *-*-* 04:00:00";
  #   playbook = "unused-modules-dry-run";
  #   profile = "read-only";
  #   dryRun = true;
  #   maxSteps = 30;
  # };
  #
  # Tool-only disk probe — LLM only if root usage >= thresholdPct
  # agent.schedules.daily-disk-probe = {
  #   enable = true;
  #   onCalendar = "*-*-* 02:45:00";
  #   kind = "probe";
  #   probe = "disk-nix";
  #   thresholdPct = 85;
  #   escalatePlaybook = "disk-nix-gc-advisor";
  # };
}
