# Generates systemd timers for scheduled agent / probe jobs
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, getModuleMetadata, ... }:

with lib;

let
  moduleName = baseNameOf ./.;
  cfg = getModuleConfig moduleName;
  ui = getModuleApi "cli-formatter";
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
      ${ui.messages.warning "ncc-assistant: kill-switch DISABLE present — skipping"}
      exit 0
    fi
    if [[ -f "$cfg/presence.json" ]] && ${pkgs.jq}/bin/jq -e '.state == "paused"' "$cfg/presence.json" >/dev/null 2>&1; then
      ${ui.messages.info "ncc-assistant: presence paused — skipping"}
      exit 0
    fi
  '';

  # --- Permission ladder (phase 39) -------------------------------------------------
  # Host config is the ceiling; a schedule only names the step it needs. Steps must stay
  # in sync with python/ncc_assistant/permissions.py (REPO_STEPS / SYSTEM_STEPS).
  repoSteps = [ "observe" "propose" "commit" "push" "pr" "merge" "release" ];
  systemSteps = [ "none" "config-write" "rebuild" ];
  # Nix has no builtins.elemIndex: rank every step once, then look the rank up.
  rankTable = steps:
    builtins.listToAttrs
      (builtins.genList (i: { name = builtins.elemAt steps i; value = i; }) (builtins.length steps));
  repoRanks = rankTable repoSteps;
  systemRanks = rankTable systemSteps;
  stepRank = ranks: name: if ranks ? ${name} then ranks.${name} else -1;
  clampStep = ranks: want: max:
    if (stepRank ranks want) > (stepRank ranks max) then max else want;
  maxStep = ranks: a: b:
    if (stepRank ranks a) >= (stepRank ranks b) then a else b;

  hostCeiling = {
    repo = cfg.grants.repoCeiling or "pr";
    system =
      if (cfg.agent.allowRebuild or false) then "rebuild"
      else if (cfg.agent.allowWrite or false) then "config-write"
      else "none";
  };

  # Legacy profile → ladder steps, so hosts that predate permissions.* keep their meaning.
  profileStepMap = {
    "chat" = { repo = "observe"; system = "none"; };
    "read-only" = { repo = "observe"; system = "none"; };
    "config-writer" = { repo = "propose"; system = "config-write"; };
    "ops" = { repo = "propose"; system = "rebuild"; };
  };
  profileSteps = profile: profileStepMap.${profile} or { repo = null; system = null; };

  effectiveGrant = schedule:
    let
      perms = schedule.permissions or {};
      dry = if (schedule.dryRun or null) != null then schedule.dryRun else (cfg.agent.dryRun or false);
      writes = if (schedule.allowWrite or null) != null then schedule.allowWrite else (cfg.agent.allowWrite or false);
      rebuilds = if (schedule.allowRebuild or null) != null then schedule.allowRebuild else (cfg.agent.allowRebuild or false);
      fromProfile = profileSteps (if (schedule.profile or null) != null then schedule.profile else (cfg.agent.profile or "read-only"));
      # Legacy hosts switch on allowWrite/allowRebuild while the profile still says
      # "read-only" (resolve_profile lets the flag override it), so the wider of the
      # two is what the schedule could do before the ladder existed.
      derivedRepo =
        if dry then "observe"
        else
          maxStep repoRanks
            (if fromProfile.repo != null then fromProfile.repo else "observe")
            (if writes then "pr" else "observe");
      derivedSystem =
        if dry then "none"
        else
          maxStep systemRanks
            (if fromProfile.system != null then fromProfile.system else "none")
            (if rebuilds then "rebuild" else if writes then "config-write" else "none");
      explicitRepo = perms.repo or null;
      explicitSystem = perms.system or null;
    in
    {
      # Derived steps never widen the host; an explicit step stays as asked so the run
      # refuses loudly instead of quietly doing less.
      repo = if explicitRepo != null then explicitRepo else clampStep repoRanks derivedRepo hostCeiling.repo;
      system =
        if explicitSystem != null then explicitSystem else clampStep systemRanks derivedSystem hostCeiling.system;
    };

  grantConflicts = filterAttrs (_: s:
    let
      perms = s.permissions or {};
      dry = if (s.dryRun or null) != null then s.dryRun else (cfg.agent.dryRun or false);
      explicitRepo = perms.repo or null;
      explicitSystem = perms.system or null;
    in
      (explicitRepo != null && (stepRank repoRanks explicitRepo) > (stepRank repoRanks hostCeiling.repo))
      || (explicitSystem != null && (stepRank systemRanks explicitSystem) > (stepRank systemRanks hostCeiling.system))
      || (dry && explicitRepo != null && (stepRank repoRanks explicitRepo) > (stepRank repoRanks "propose"))
  ) enabledSchedules;

  mkAgentExec = name: schedule:
    let
      maxSteps = if schedule.maxSteps != null then schedule.maxSteps else (cfg.agent.maxSteps or (-1));
      dryRun = if schedule.dryRun != null then schedule.dryRun else (cfg.agent.dryRun or false);
      profile = if schedule.profile != null then schedule.profile else (cfg.agent.profile or "read-only");
      playbook = schedule.playbook or null;
      goal = schedule.goal or null;
      grant = effectiveGrant schedule;
      agentArgs = [
        "${pkg.nccAssistant}/bin/ncc-assistant"
        "agent" "run"
      ] ++ optionals (maxSteps > 0) [ "--max-steps" (toString maxSteps) ]
        ++ [ "--grant" "repo=${grant.repo}" "--grant" "system=${grant.system}" ]
        ++ optionals (profile != null) [ "--profile" (lib.escapeShellArg profile) ]
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
      ${ui.messages.loading "ncc-assistant: running probe ${probe} (threshold=${thr})"}
      exec ${concatStringsSep " " probeArgs}
    '';

  mkScheduleService = name: schedule:
    let
      grant = effectiveGrant schedule;
      writes = (stepRank systemRanks grant.system) >= (stepRank systemRanks "config-write");
      rebuilds = grant.system == "rebuild";
    in {
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
        # Derived from this schedule's grant — the unit is the narrowest scope, so it
        # writes only what its own step allows (ncc ai permissions show).
        AGENT_ALLOW_WRITE = if writes then "1" else "0";
        AGENT_ALLOW_REBUILD = if rebuilds then "1" else "0";
        NCC_ASSISTANT_AGENT_ALLOW_WRITE = if writes then "1" else "0";
        NCC_ASSISTANT_AGENT_ALLOW_REBUILD = if rebuilds then "1" else "0";
        # Named per schedule: "schedule" says a timer fired, "schedule:<id>" says which one, so
        # audit.jsonl and `ncc ai approve list` can be read per unit. notifications.is_schedule_actor
        # accepts both spellings, so an older hand-set env value still counts.
        NCC_ASSISTANT_ACTOR = "schedule:${name}";
        NCC_ASSISTANT_GRANT_REPO_CEILING = hostCeiling.repo;
        # No NOTIFY_ON_* here on purpose: schedules have no per-schedule notify option, and
        # anything set in this unit outranks agent.notifications.* — the wrapper keeps the
        # host value unless the narrowest scope declared its own.
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
      warnings = mapAttrsToList (name: s:
        let
          perms = s.permissions or {};
          dry = if (s.dryRun or null) != null then s.dryRun else (cfg.agent.dryRun or false);
        in
          ''
            ncc-assistant: schedule '${name}' asks for repo=${perms.repo or "-"} system=${perms.system or "-"}
            above this host's ceiling repo=${hostCeiling.repo} system=${hostCeiling.system}${optionalString dry " (and dryRun=true)"};
            the run will refuse instead of quietly doing less. Lower permissions.* or raise
            agent.grants.repoCeiling / agent.allowWrite / agent.allowRebuild.
          '') grantConflicts;

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
