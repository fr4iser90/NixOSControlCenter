# Generates systemd timers for scheduled agent / probe jobs
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  pkg = import ./package.nix { inherit pkgs lib cfg getModuleApi getModuleMetadata; };

  enabledSchedules = filterAttrs (_: s: s.enable or true) (cfg.agent.schedules or { });
  hasSchedules = enabledSchedules != { };

  scheduleHasWork = _: s:
    let
      kind = s.kind or "agent";
    in
    if kind == "probe" then
      ((s.probe or null) != null && s.probe != "")
    else
      ((s.goal or null) != null && s.goal != "")
      || ((s.playbook or null) != null && s.playbook != "");

  invalidSchedules = filterAttrs (_: s: !(scheduleHasWork _ s)) enabledSchedules;

  mkHomePreamble = ''
    set -euo pipefail
    if [[ "$(id -u)" -eq 0 ]]; then
      for u in ${lib.concatStringsSep " " (attrNames (filterAttrs (_: u: u.isNormalUser or false) config.users.users))}; do
        home=$(getent passwd "$u" | cut -d: -f6 || true)
        if [[ -n "$home" && -d "$home/.config/ncc-assistant" ]]; then
          export HOME="$home"
          export XDG_CONFIG_HOME="$home/.config"
          export USER="$u"
          break
        fi
      done
    fi
    cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/ncc-assistant"
    if [[ -f "$cfg/DISABLE" ]]; then
      echo "ncc-assistant: kill-switch DISABLE present — skipping" >&2
      exit 0
    fi
    if [[ -f "$cfg/presence.json" ]] && ${pkgs.jq}/bin/jq -e '.state == "paused"' "$cfg/presence.json" >/dev/null 2>&1; then
      echo "ncc-assistant: presence paused — skipping" >&2
      exit 0
    fi
  '';

  mkAgentExec = name: schedule:
    let
      maxSteps = if schedule.maxSteps != null then toString schedule.maxSteps else toString (cfg.agent.maxSteps or 24);
      dryRun = if schedule.dryRun != null then schedule.dryRun else (cfg.agent.dryRun or false);
      profile = if schedule.profile != null then schedule.profile else (cfg.agent.profile or "read-only");
      playbook = schedule.playbook or null;
      goal = schedule.goal or null;
      agentArgs = [
        "${pkg.nccAssistant}/bin/ncc-assistant"
        "agent" "run"
        "--max-steps" maxSteps
      ] ++ optionals (profile != null) [ "--profile" (lib.escapeShellArg profile) ]
        ++ optionals dryRun [ "--dry-run" ]
        ++ optionals (playbook != null) [ "--playbook" (lib.escapeShellArg playbook) ]
        ++ optionals (goal != null && goal != "") [ "--goal" (lib.escapeShellArg goal) ];
    in
    pkgs.writeShellScript "ncc-assistant-schedule-${name}" ''
      ${mkHomePreamble}
      exec ${concatStringsSep " " agentArgs}
    '';

  mkProbeExec = name: schedule:
    let
      probe = schedule.probe or "disk-nix";
      thr = toString (schedule.thresholdPct or 85);
      pb = schedule.escalatePlaybook or "disk-nix-gc-advisor";
      probeArgs = [
        "${pkg.nccAssistant}/bin/ncc-assistant"
        "probe" "disk"
        "--threshold" thr
        "--escalate"
        "--playbook" (lib.escapeShellArg pb)
      ];
    in
    pkgs.writeShellScript "ncc-assistant-schedule-${name}" ''
      ${mkHomePreamble}
      echo "ncc-assistant: running probe ${probe} (threshold=${thr})"
      exec ${concatStringsSep " " probeArgs}
    '';

  mkScheduleService = name: schedule: {
    "ncc-assistant-schedule-${name}" = {
      description = "NCC Assistant scheduled job: ${name}";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        ExecStart =
          if (schedule.kind or "agent") == "probe"
          then "${mkProbeExec name schedule}"
          else "${mkAgentExec name schedule}";
        StandardOutput = "journal";
        StandardError = "journal";
      };

      environment = {
        NCC_ASSISTANT_ROOT = "${pkg.appRoot}";
        NCC_KNOWLEDGE_ROOT = "${pkg.appRoot}/knowledge";
        NCC_PROMPTS_ROOT = "${pkg.appRoot}/prompts";
        AGENT_CONFIRM = "writes";
        AGENT_ALLOW_WRITE = "0";
        AGENT_ALLOW_REBUILD = "0";
        NOTIFY_ON_JOB_END = "1";
      } // optionalAttrs (schedule.model != null) {
        NCC_ASSISTANT_MODEL = schedule.model;
      } // optionalAttrs ((cfg.model or null) != null && schedule.model == null) {
        NCC_ASSISTANT_MODEL = cfg.model;
      };
    };
  };

  mkScheduleTimer = name: schedule: {
    "ncc-assistant-schedule-${name}" = {
      description = "Timer for NCC Assistant scheduled job: ${name}";
      wantedBy = [ "timers.target" ];

      timerConfig = {
        OnCalendar = schedule.onCalendar;
        Persistent = schedule.persistent or true;
        RandomizedDelaySec =
          if name == "weekly-module-audit" then "15min"
          else if name == "daily-disk-probe" then "10min"
          else "5min";
      };
    };
  };

  dangerousSchedules = filterAttrs (_: s: (s.allowRebuild or cfg.agent.allowRebuild or false) == true) enabledSchedules;
  hasDangerousSchedules = dangerousSchedules != { };
in
{
  config = mkIf (cfg.enable or false) (mkMerge [
    (mkIf hasSchedules {
      systemd.services = mkMerge (mapAttrsToList mkScheduleService enabledSchedules);
      systemd.timers = mkMerge (mapAttrsToList mkScheduleTimer enabledSchedules);
    })

    {
      assertions = [
        {
          assertion = !hasDangerousSchedules || (cfg.forceDangerous or false);
          message = ''
            NCC Assistant schedules with allowRebuild=true detected:
            ${concatStringsSep ", " (attrNames dangerousSchedules)}

            Scheduled rebuilds are dangerous without human supervision.
            Set ncc-assistant.forceDangerous = true to acknowledge this risk.
          '';
        }
        {
          assertion = invalidSchedules == { };
          message = ''
            NCC Assistant schedules need goal/playbook (agent) or probe id (probe):
            ${concatStringsSep ", " (attrNames invalidSchedules)}
          '';
        }
      ];
    }
  ]);
}
