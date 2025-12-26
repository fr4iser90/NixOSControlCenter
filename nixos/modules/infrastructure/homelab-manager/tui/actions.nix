# Homelab Manager TUI Actions
# Handles TUI menu selections by calling appropriate CLI commands

{ config, lib, pkgs, ... }:

let
  # Get UI utilities
  ui = config.${builtins.getModuleApi "cli-formatter"};

  # Helper function to execute CLI commands
  executeCommand = action: args: ''
    ${ui.badges.info "Executing: ncc homelab ${action} ${lib.concatStringsSep " " args}"}
    if ncc homelab "${action}" ${lib.concatStringsSep " " args}; then
      ${ui.badges.success "Command completed successfully"}
    else
      ${ui.badges.error "Command failed"}
      return 1
    fi
  '';

in
pkgs.writeShellScriptBin "homelab-tui-actions" ''
  #!/bin/bash
  set -e

  # Get the selected action from TUI menu
  SELECTED_ACTION="$1"
  shift  # Remove action from args, rest are parameters

  case "$SELECTED_ACTION" in
    "status")
      ${executeCommand "status" []}
      ;;

    "init-swarm")
      ${ui.badges.warning "⚠️  This will initialize a new Docker Swarm on this node"}
      ${ui.messages.info "Make sure Docker is running and no existing Swarm exists"}
      ${ui.prompts.input "Continue? (y/N): "}
      read -r confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        ${executeCommand "init-swarm" []}
      else
        ${ui.messages.info "Swarm initialization cancelled"}
      fi
      ;;

    "join-swarm")
      ${ui.badges.info "🔗 Join Docker Swarm"}
      ${ui.messages.info "You'll need the join token from the manager node"}
      ${ui.prompts.input "Manager IP: "}
      read -r manager_ip
      ${ui.prompts.input "Join token: "}
      read -r join_token
      ${ui.prompts.input "Join as manager? (y/N): "}
      read -r as_manager
      if [[ "$as_manager" =~ ^[Yy]$ ]]; then
        ${executeCommand "join-swarm" ["--manager" "$manager_ip" "$join_token"]}
      else
        ${executeCommand "join-swarm" ["--worker" "$manager_ip" "$join_token"]}
      fi
      ;;

    "deploy-stack")
      ${ui.badges.info "📦 Deploy Docker Stack"}
      ${ui.prompts.input "Stack name: "}
      read -r stack_name
      ${ui.prompts.input "Compose file path: "}
      read -r compose_file

      if [ -f "$compose_file" ]; then
        ${executeCommand "deploy-stack" ["$stack_name" "$compose_file"]}
      else
        ${ui.badges.error "Compose file not found: $compose_file"}
      fi
      ;;

    "list-stacks")
      ${executeCommand "list-stacks" []}
      ;;

    "remove-stack")
      ${ui.badges.warning "🛑 Remove Docker Stack"}
      ${ui.prompts.input "Stack name to remove: "}
      read -r stack_name

      if [ -n "$stack_name" ]; then
        ${ui.prompts.input "Are you sure you want to remove stack '$stack_name'? (y/N): "}
        read -r confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          ${executeCommand "remove-stack" ["$stack_name"]}
        else
          ${ui.messages.info "Stack removal cancelled"}
        fi
      fi
      ;;

    "configure")
      ${ui.badges.info "⚙️ Configure Homelab"}
      ${ui.messages.info "Opening configuration editor..."}
      ${executeCommand "configure" []}
      ;;

    "update-services")
      ${ui.badges.warning "🔄 Update All Services"}
      ${ui.messages.info "This will update all services in all stacks"}
      ${ui.prompts.input "Continue? (y/N): "}
      read -r confirm
      if [[ "$confirm" =~ ^[Yy]$ ]]; then
        ${executeCommand "update-services" []}
      fi
      ;;

    "logs")
      ${ui.badges.info "📋 Service Logs"}
      ${ui.prompts.input "Service name (or 'all' for all services): "}
      read -r service_name
      ${ui.prompts.input "Number of lines (default: 50): "}
      read -r lines
      lines="''${lines:-50}"

      if [ "$service_name" = "all" ]; then
        ${executeCommand "logs" ["--all" "--lines" "$lines"]}
      else
        ${executeCommand "logs" ["$service_name" "--lines" "$lines"]}
      fi
      ;;

    "inspect-stack")
      ${ui.badges.info "🔍 Inspect Stack"}
      ${ui.prompts.input "Stack name to inspect: "}
      read -r stack_name
      ${executeCommand "inspect-stack" ["$stack_name"]}
      ;;

    *)
      ${ui.badges.error "Unknown action: $SELECTED_ACTION"}
      exit 1
      ;;
  esac

  # Pause before returning to menu
  ${ui.text.newline}
  ${ui.messages.info "Press Enter to continue..."}
  read -r
''
