# Command Center Utility Functions
{ config, lib, pkgs, systemConfig, getModuleConfig, getModuleApi, ... }:

let
  ui = getModuleApi "cli-formatter";
  nccConfig = getModuleConfig "nixos-control-center";
  dangerousIgnore = if (nccConfig.dangerousIgnore or false) then "true" else "false";
in
{
  # Generate case blocks for command execution
  generateExecCase = cmd: let
    permission = cmd.permission or null;
    dangerous = if cmd.dangerous or false then "true" else "false";
    requiresSudo = if cmd.requiresSudo or false then "true" else "false";
    userApi = getModuleApi "user";
    userModuleCfg = getModuleConfig "user";
    # Verwende userAttrs aus der bestehenden user config (wie in user/config.nix)
    userAttrs = lib.filterAttrs (n: v: builtins.isAttrs v) userModuleCfg;
    
    # Hierarchical only: with parent, match `parent-name` exclusively (no bare-name aliases).
    # Example: parent=lock name=discover → only `lock-discover` (`ncc lock discover`).
    parentName = cmd.parent or null;
    hierarchicalName = if parentName != null then "${parentName}-${cmd.name}" else null;
    casePattern = if hierarchicalName != null
      then "${hierarchicalName})"
      else "${cmd.name})";
  in ''
      ${casePattern}
      ${if permission != null then ''
        # Prefer elevating identity (pkexec/sudo) — root itself is not an NCC role
        if [ -n "''${PKEXEC_UID:-}" ]; then
          current_user=$(getent passwd "$PKEXEC_UID" | cut -d: -f1)
        elif [ -n "''${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
          current_user="$SUDO_USER"
        else
          current_uid=$(id -ru)
          current_user=$(getent passwd "$current_uid" | cut -d: -f1)
        fi

        # Fallback if getent fails
        if [ -z "$current_user" ]; then
          current_user="unknown"
        fi

        # Get user role from the configured users (using userAttrs lookup)
        ${lib.concatStringsSep "\n        " (lib.mapAttrsToList (username: userConfig: ''
        if [ "$current_user" = "${username}" ]; then
          user_role="${userConfig.role or "guest"}"
        fi'') userAttrs)}

        # If user not found in config, default to guest
        if [ -z "$user_role" ]; then
          user_role="guest"
        fi

        # Check permission based on role
        permission_granted=false
        case "$user_role" in
          "admin")
            # Admins have all permissions
            permission_granted=true
            ;;
          "restricted-admin")
            case "${permission}" in
              system.update|system.build|system.check.*|user.*|package.*|module.*|network.read)
                permission_granted=true
                ;;
            esac
            ;;
          "virtualization")
            case "${permission}" in
              system.check.self|user.read.self|package.docker|package.podman|package.user.self)
                permission_granted=true
                ;;
            esac
            ;;
          *)
            # Guest users
            case "${permission}" in
              system.check.self|user.read.self|package.user.self)
                permission_granted=true
                ;;
            esac
            ;;
        esac

        if [ "$permission_granted" != "true" ]; then
          ${ui.badges.error "Permission denied: Need capability '${permission}'"}
          exit 1
        fi
      '' else ""}

      if [ "${dangerous}" = "true" ] && [ "${dangerousIgnore}" != "true" ]; then
        ${ui.messages.warning "⚠️  WARNING: This command is potentially dangerous!"}
        ${ui.messages.info "This may cause system instability or data loss."}
        printf "Do you want to continue? (yes/no): "
        read confirmation
        case $confirmation in
          yes|YES|y|Y)
            ${ui.messages.info "Proceeding with dangerous command..."}
            ;;
          *)
            ${ui.messages.info "Command cancelled by user."}
            exit 0
            ;;
        esac
      fi
      if [ "${requiresSudo}" = "true" ]; then
        exec sudo "${cmd.script}" "$@"
      else
        exec "${cmd.script}" "$@"
      fi
      ;;
  '';

  # Generate case blocks for detailed help
  generateLongHelpCase = cmd: ''
    ${cmd.name})
      echo "${cmd.longHelp}"
      ;;
  '';

  # Get unique categories from commands
  getUniqueCategories = commands:
    lib.unique (lib.map (command: command.category) commands);

  # Generate command list string (only show top-level commands without parent)
  generateCommandList = commands:
    let
      topLevelCommands = lib.filter (cmd: (cmd.parent or null) == null && !(cmd.internal or false)) commands;
    in
      lib.concatMapStringsSep "\n" (cmd: "  ${cmd.name} - ${cmd.description}") topLevelCommands;

  # Get valid commands string
  getValidCommands = commands:
    lib.concatStringsSep " " (map (cmd: cmd.name) commands);
}
