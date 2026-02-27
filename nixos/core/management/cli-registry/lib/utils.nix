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
    
    # Hierarchical command support: if command has parent, also match "parent-name"
    parentName = cmd.parent or null;
    hierarchicalName = if parentName != null then "${parentName}-${cmd.name}" else null;
    
    # Generate case pattern: "name|parent-name)" if hierarchical, else just "name)"
    casePattern = if hierarchicalName != null 
      then "${cmd.name}|${hierarchicalName})"
      else "${cmd.name})";
  in ''
      ${casePattern}
      ${if permission != null then ''
        # Get current user securely via UID (not spoofable)
        current_uid=$(id -ru)
        current_user=$(getent passwd "$current_uid" | cut -d: -f1)

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
              "system.update"|"system.build"|"system.check.*")
                permission_granted=true
                ;;
            esac
            ;;
          "virtualization")
            case "${permission}" in
              "system.check.self"|"user.read.self"|"package.docker"|"package.podman")
                permission_granted=true
                ;;
            esac
            ;;
          *)
            # Guest users
            case "${permission}" in
              "system.check.self"|"user.read.self")
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
