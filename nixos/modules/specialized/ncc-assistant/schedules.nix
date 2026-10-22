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
  minStep = ranks: a: b:
    if (stepRank ranks a) <= (stepRank ranks b) then a else b;

  # Two knobs set the system ceiling and a run is held to the lower of them, exactly as
  # resolve_run_grant does: the host pair (exported as NCC_ASSISTANT_ALLOW_*) and the agent
  # pair (exported as NCC_ASSISTANT_AGENT_ALLOW_*). Reading only the agent pair generated a
  # unit with AGENT_ALLOW_WRITE=1 on a host whose allowWrite=false: eval called that grant
  # fine and the run refused at the first write.
  pairStep = allowWrite: allowRebuild:
    if allowRebuild then "rebuild" else if allowWrite then "config-write" else "none";
  hostCeiling = {
    repo = cfg.grants.repoCeiling or "pr";
    system = minStep systemRanks
      (pairStep (cfg.allowWrite or true) (cfg.allowRebuild or false))
      (pairStep (cfg.agent.allowWrite or false) (cfg.agent.allowRebuild or false));
  };
  # A declared true in the agent pair cannot open what the host pair closed — the pair only
  # narrows, so the knob that was reached for is exactly the one with no effect here.
  ceilingInversions =
    optionals (!(cfg.allowWrite or true) && (cfg.agent.allowWrite or false)) [
      ''
        ncc-assistant: agent.allowWrite = true cannot open writes that allowWrite = false closed.
        The agent pair only narrows the host pair, so this host's system ceiling stays
        ${hostCeiling.system}. Set allowWrite = true as well, or drop agent.allowWrite.
      ''
    ]
    ++ optionals (!(cfg.allowRebuild or false) && (cfg.agent.allowRebuild or false)) [
      ''
        ncc-assistant: agent.allowRebuild = true cannot open rebuilds that allowRebuild = false
        closed. The agent pair only narrows the host pair, so this host's system ceiling stays
        ${hostCeiling.system}. Set allowRebuild = true as well, or drop agent.allowRebuild.
      ''
    ];

  # Per-day budgets (phase 39 L8). A schedule may only narrow the host's counters; a
  # counter neither side sets stays out of the environment so budgets.py keeps its own
  # default. 0 means "no cap here", so it outranks nothing but never lifts a cap.
  budgetKeys = {
    maxRunsPerDay = "NCC_ASSISTANT_BUDGET_MAX_RUNS_PER_DAY";
    maxPrsPerDay = "NCC_ASSISTANT_BUDGET_MAX_PRS_PER_DAY";
    maxDiffLines = "NCC_ASSISTANT_BUDGET_MAX_DIFF_LINES";
    maxOpenAgentPrs = "NCC_ASSISTANT_BUDGET_MAX_OPEN_AGENT_PRS";
  };
  budgetCapped = value: value != null && value != 0;
  budgetValue = budget: key:
    let
      want = budget.${key} or null;
      ceiling = (cfg.grants.budget or { }).${key} or null;
    in
      if !budgetCapped want && !budgetCapped ceiling then
        (if want == 0 || ceiling == 0 then 0 else null)
      else if !budgetCapped want then ceiling
      else if !budgetCapped ceiling then want
      else if want <= ceiling then want
      else ceiling;
  budgetOverreach = budget: key:
    let
      want = budget.${key} or null;
      ceiling = (cfg.grants.budget or { }).${key} or null;
    in
      budgetCapped want && budgetCapped ceiling && want > ceiling;
  budgetEnvironment = schedule:
    let budget = (schedule.permissions or { }).budget or { }; in
    mapAttrs' (key: var: nameValuePair var (toString (budgetValue budget key)))
      # filterAttrs calls the predicate name: value — here the name is the budget key and
      # the value its env var, so the lookup has to use the first argument.
      (filterAttrs (key: _: (budgetValue budget key) != null) budgetKeys);
  scheduleBudget = s: (s.permissions or { }).budget or { };
  budgetConflicts = filterAttrs (_: s:
    any (k: budgetOverreach (scheduleBudget s) k) (attrNames budgetKeys)
  ) enabledSchedules;

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

  # A submodule option the host never set is null, not missing, and `attrs.x or d` only covers
  # the missing case — interpolating the null aborts evaluation with "cannot coerce null to a
  # string", so the config error replaces the very message meant to explain it.
  shownStep = value: if value == null then "-" else value;

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

  # A profile is not a label: its built-in flags are what open the write and rebuild tools —
  # resolve_profile keeps them unless the grant lowers them, and nothing raises them (an agent
  # run hands resolve_profile no override at all). So a schedule whose step sits above its own
  # profile's reach carries a grant it can never spend: the ladder says yes, the tool catalog
  # holds no write tool, and the attempt dies in the profile check instead of the audit trail.
  # The aliases are here because profiles.py resolves them; deliberately not merged into
  # profileStepMap, which derives steps and must never widen what a unit is handed.
  profileSystemReach = {
    chat = "none";
    "read-only" = "none";
    "config-writer" = "config-write";
    cautious = "config-write";
    ops = "rebuild";
    autonomous = "rebuild";
  };
  scheduleProfile = s:
    if (s.profile or null) != null then s.profile else (cfg.agent.profile or "read-only");
  # A name this module does not know reaches nothing: resolve_profile falls back to read-only,
  # so the typo costs the run its writes rather than passing this check quietly.
  profileReach = s: profileSystemReach.${scheduleProfile s} or "none";
  profileConflicts = filterAttrs (_: s:
    (stepRank systemRanks (effectiveGrant s).system) > (stepRank systemRanks (profileReach s))
  ) enabledSchedules;

  # --- Poll trigger (phase 39 L11) ---------------------------------------------------
  # A poll earns its keep only by skipping the run when nothing moved: the timer fires every
  # interval and python/ncc_assistant/poll_guard.py compares a hash of what pollWatch names
  # against the last run's, exiting before the LLM call. So the watch list is not decoration —
  # without it the schedule is a calendar timer that pays for a model every 15 minutes, which
  # is the cost this whole feature exists to avoid. Reject it at evaluation.
  isPoll = schedule: (schedule.trigger or "calendar") == "poll";
  pollInterval = schedule:
    if (schedule.pollInterval or null) != null && schedule.pollInterval != "" then
      schedule.pollInterval
    else
      null;
  # The same grammar poll_guard.py parses; an unknown prefix here means the author meant
  # something else, and a watch entry that silently matches nothing is an always-unchanged —
  # or never-unchanged — schedule discovered at 3am instead of at rebuild.
  watchEntryOk = entry:
    builtins.match "workspace:[a-z0-9][a-z0-9._-]*" entry != null
    || builtins.match "file:/[A-Za-z0-9._/-]+" entry != null;
  # A submodule option the host never set is present as null, and `attrs.x or d` only covers a
  # *missing* attribute — so the nullable onCalendar/pollWatch have to be unwrapped by hand.
  # Interpolating them raw aborts evaluation; comparing them raw reads a null watch as "set".
  calendarOf = schedule: if (schedule.onCalendar or null) == null then "" else schedule.onCalendar;
  watchListOf = schedule: if (schedule.pollWatch or null) == null then [ ] else schedule.pollWatch;
  triggerProblems = name: schedule:
    let
      poll = isPoll schedule;
      watch = watchListOf schedule;
      badWatch = filter (entry: !watchEntryOk entry) watch;
    in
      optionals (poll && (schedule.kind or "agent") != "agent") [
        ''
          trigger = poll needs kind = "agent": the change-hash gate lives in the agent run, so a
          probe with trigger = poll would fire every ${toString (pollInterval schedule)} whether
          or not anything changed. Use trigger = calendar, or make it an agent schedule.
        ''
      ]
      ++ optionals (poll && pollInterval schedule == null) [
        ''
          trigger = poll needs pollInterval (a systemd time span, e.g. "15min"). Without it the
          timer has no OnBootSec=/OnUnitActiveSec= and never fires — the schedule would look
          configured and run never.
        ''
      ]
      ++ optionals (poll && watch == [ ]) [
        ''
          trigger = poll needs a non-empty pollWatch. Nothing to compare means nothing to skip on,
          so every interval becomes a full agent run. Name what to hash:
          pollWatch = [ "workspace:<id>" "file:/abs/path" ].
        ''
      ]
      ++ optionals (poll && badWatch != [ ]) [
        ''
          pollWatch entries unusable: ${concatStringsSep ", " badWatch}
          (expected "workspace:<registered-id>" or "file:/absolute/path" — no "~", no comma, no
          other prefix). An entry the guard cannot resolve would make every poll look unchanged.
        ''
      ]
      ++ optionals (!poll && calendarOf schedule == "") [
        ''
          trigger = calendar needs onCalendar (e.g. "daily", "*-*-* 03:00:00"), or set
          trigger = poll with pollInterval + pollWatch. A timer with neither trigger never fires.
        ''
      ]
      # Both of these are a schedule that reads one way and behaves another: the operator sees a
      # change-driven job in their config while the unit runs on the clock, or the reverse.
      ++ optionals (poll && (schedule.onCalendar or null) != null) [
        ''
          trigger = poll ignores onCalendar: a poll is monotonic (OnBootSec/OnUnitActiveSec), so
          the calendar expression here is never applied. Remove onCalendar, or set
          trigger = calendar if the wall clock is what you actually want.
        ''
      ]
      ++ optionals (!poll && watch != [ ]) [
        ''
          pollWatch is only read by a poll: with trigger = calendar nothing compares it, so the
          run happens on the clock whatever the tree did. Set trigger = poll with pollInterval,
          or drop pollWatch.
        ''
      ]
      ++ optionals (poll && name == "") [
        "trigger = poll needs a schedule id (unit name)."
      ];
  triggerErrors = filterAttrs (name: s: triggerProblems name s != [ ]) enabledSchedules;

  # The guard reads these off the unit's own environment: the schedule id keys its stored hash,
  # so two polls on one host never overwrite each other's idea of "already acted on this".
  pollEnvironment = name: schedule:
    optionalAttrs (isPoll schedule) {
      NCC_ASSISTANT_POLL_SCHEDULE = name;
      NCC_ASSISTANT_POLL_INTERVAL = pollInterval schedule;
      NCC_ASSISTANT_POLL_WATCH = concatStringsSep "," (watchListOf schedule);
    };

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
      } // budgetEnvironment schedule // pollEnvironment name schedule
        // optionalAttrs (schedule.model != null) {
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

      # A poll is a monotonic timer: OnCalendar would fire it at wall-clock times as well, so
      # the schedule would do both jobs, and Persistent is about calendar slots the host
      # missed while powered off — a monotonic timer has none. Both stay on the calendar arm.
      timerConfig =
        (if isPoll schedule then {
          OnBootSec = pollInterval schedule;
          OnUnitActiveSec = pollInterval schedule;
        } else {
          OnCalendar = schedule.onCalendar;
          Persistent = schedule.persistent or true;
        })
        // {
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
            ncc-assistant: schedule '${name}' asks for repo=${shownStep perms.repo} system=${shownStep perms.system}
            above this host's ceiling repo=${hostCeiling.repo} system=${hostCeiling.system}${optionalString dry " (and dryRun=true)"};
            the run will refuse instead of quietly doing less. Lower permissions.* or raise
            agent.grants.repoCeiling / allowWrite / allowRebuild / agent.allowWrite /
            agent.allowRebuild — the ceiling is the lower of the host and agent pair.
          '') grantConflicts
        ++ mapAttrsToList (name: s:
          ''
            ncc-assistant: schedule '${name}' runs profile '${scheduleProfile s}', which reaches
            system=${profileReach s}, but its grant carries system=${(effectiveGrant s).system}.
            A profile is what opens the write/rebuild tools and a grant may only narrow it, so
            every write this run attempts dies in the profile check. Set a profile that reaches
            the step (config-writer / ops) or lower permissions.system / allowWrite / allowRebuild.
          '') profileConflicts
        ++ mapAttrsToList (name: s:
          ''
            ncc-assistant: schedule '${name}' asks for budget ${concatStringsSep ", "
              (map (k: "${k}=${toString ((scheduleBudget s).${k})}")
                (filter (k: budgetOverreach (scheduleBudget s) k) (attrNames budgetKeys)))}
            above agent.grants.budget; the host value is what the unit gets. Budgets narrow,
            they never widen.
          '') budgetConflicts
        ++ ceilingInversions;

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
        {
          assertion = triggerErrors == { };
          message = ''
            NCC Assistant schedules have a trigger that cannot work:
            ${concatStringsSep "\n" (mapAttrsToList (name: s:
              "- ${name}: ${concatStringsSep "\n  " (triggerProblems name s)}") triggerErrors)}
          '';
        }
      ];
    }
  ]);
}
