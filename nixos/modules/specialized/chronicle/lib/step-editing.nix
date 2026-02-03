# Step Editing System
# Edit, delete, reorder, merge, and split recording steps
# - Interactive step manipulation
# - JSON-based editing
# - Undo/redo support
# - Batch operations

{ config, lib, pkgs, ... }:

let
  cfg = config.services.nixos-control-center.chronicle;

in {
  # Step editing script
  stepEditingScript = pkgs.writeShellScriptBin "chronicle-edit" ''
    #!${pkgs.bash}/bin/bash
    # Step Editing System
    # Version: 1.2.0
    
    set -euo pipefail
    
    # State directory
    STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}/nixos-chronicle"
    UNDO_DIR="$STATE_DIR/undo"
    
    # Logging
    LOG_FILE="$STATE_DIR/step-editing.log"
    
    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
    }
    
    # Initialize undo system
    init_undo() {
      mkdir -p "$UNDO_DIR"
    }
    
    # Save undo state
    save_undo() {
      local session_file="$1"
      local timestamp=$(date +%s)
      local undo_file="$UNDO_DIR/$(basename "$session_file").$timestamp.undo"
      
      cp "$session_file" "$undo_file"
      log "Undo state saved: $undo_file"
      
      # Keep only last 10 undo states
      ls -t "$UNDO_DIR"/$(basename "$session_file").*.undo 2>/dev/null | tail -n +11 | xargs -r rm
    }
    
    # List all sessions
    list_sessions() {
      local output_dir="''${CHRONICLE_OUTPUT_DIR:-$HOME/.local/share/step-records}"
      
      echo "Available Recording Sessions:"
      echo "=============================="
      echo
      
      for session_dir in "$output_dir"/*; do
        if [[ -d "$session_dir" && -f "$session_dir/metadata.json" ]]; then
          local session_name=$(basename "$session_dir")
          local title=$(${pkgs.jq}/bin/jq -r '.title // "Untitled"' "$session_dir/metadata.json")
          local steps=$(${pkgs.jq}/bin/jq '.steps | length' "$session_dir/metadata.json")
          local date=$(${pkgs.jq}/bin/jq -r '.startTime // "Unknown"' "$session_dir/metadata.json")
          
          echo "📁 $session_name"
          echo "   Title: $title"
          echo "   Steps: $steps"
          echo "   Date: $date"
          echo
        fi
      done
    }
    
    # List steps in a session
    list_steps() {
      local session_file="$1"
      
      if [[ ! -f "$session_file" ]]; then
        echo "Error: Session file not found: $session_file"
        return 1
      fi
      
      echo "Steps in session:"
      echo "================="
      echo
      
      ${pkgs.jq}/bin/jq -r '.steps[] | "\(.id). [\(.timestamp)] \(.action // "Unknown") - \(.description // "No description")"' "$session_file"
    }
    
    # Edit step metadata
    edit_step() {
      local session_file="$1"
      local step_id="$2"
      
      if [[ ! -f "$session_file" ]]; then
        echo "Error: Session file not found"
        return 1
      fi
      
      # Save undo state
      save_undo "$session_file"
      
      # Get current step data
      local current_desc=$(${pkgs.jq}/bin/jq -r ".steps[] | select(.id == $step_id) | .description // \"\"" "$session_file")
      local current_action=$(${pkgs.jq}/bin/jq -r ".steps[] | select(.id == $step_id) | .action // \"\"" "$session_file")
      
      echo "Editing Step #$step_id"
      echo "Current description: $current_desc"
      echo "Current action: $current_action"
      echo
      
      # Interactive editing
      read -p "New description (Enter to keep current): " new_desc
      read -p "New action (Enter to keep current): " new_action
      
      # Update if changed
      if [[ -n "$new_desc" ]]; then
        ${pkgs.jq}/bin/jq "(.steps[] | select(.id == $step_id) | .description) = \"$new_desc\"" \
          "$session_file" > "$session_file.tmp"
        mv "$session_file.tmp" "$session_file"
      fi
      
      if [[ -n "$new_action" ]]; then
        ${pkgs.jq}/bin/jq "(.steps[] | select(.id == $step_id) | .action) = \"$new_action\"" \
          "$session_file" > "$session_file.tmp"
        mv "$session_file.tmp" "$session_file"
      fi
      
      log "Edited step #$step_id in $session_file"
      echo "Step #$step_id updated successfully"
    }
    
    # Delete step
    delete_step() {
      local session_file="$1"
      local step_id="$2"
      
      if [[ ! -f "$session_file" ]]; then
        echo "Error: Session file not found"
        return 1
      fi
      
      # Show step to delete
      local step_desc=$(${pkgs.jq}/bin/jq -r ".steps[] | select(.id == $step_id) | .description // \"No description\"" "$session_file")
      
      echo "Delete Step #$step_id: $step_desc"
      read -p "Are you sure? (y/N): " confirm
      
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 0
      fi
      
      # Save undo state
      save_undo "$session_file"
      
      # Delete step and renumber remaining steps
      ${pkgs.jq}/bin/jq "del(.steps[] | select(.id == $step_id)) | .steps |= to_entries | .steps |= map(.value.id = .key + 1 | .value) | .stepCount = (.steps | length)" \
        "$session_file" > "$session_file.tmp"
      mv "$session_file.tmp" "$session_file"
      
      log "Deleted step #$step_id from $session_file"
      echo "Step #$step_id deleted successfully"
    }
    
    # Reorder step
    reorder_step() {
      local session_file="$1"
      local step_id="$2"
      local new_position="$3"
      
      if [[ ! -f "$session_file" ]]; then
        echo "Error: Session file not found"
        return 1
      fi
      
      # Save undo state
      save_undo "$session_file"
      
      # Extract the step to move
      local step_data=$(${pkgs.jq}/bin/jq ".steps[] | select(.id == $step_id)" "$session_file")
      
      # Remove step from current position
      ${pkgs.jq}/bin/jq "del(.steps[] | select(.id == $step_id))" "$session_file" > "$session_file.tmp"
      
      # Insert at new position
      ${pkgs.jq}/bin/jq --argjson step "$step_data" --argjson pos "$((new_position - 1))" \
        '.steps |= (.[0:$pos] + [$step] + .[$pos:]) | .steps |= to_entries | .steps |= map(.value.id = .key + 1 | .value)' \
        "$session_file.tmp" > "$session_file"
      rm "$session_file.tmp"
      
      log "Reordered step #$step_id to position $new_position in $session_file"
      echo "Step #$step_id moved to position $new_position"
    }
    
    # Merge steps
    merge_steps() {
      local session_file="$1"
      local step_id1="$2"
      local step_id2="$3"
      
      if [[ ! -f "$session_file" ]]; then
        echo "Error: Session file not found"
        return 1
      fi
      
      # Save undo state
      save_undo "$session_file"
      
      # Get step data
      local desc1=$(${pkgs.jq}/bin/jq -r ".steps[] | select(.id == $step_id1) | .description // \"\"" "$session_file")
      local desc2=$(${pkgs.jq}/bin/jq -r ".steps[] | select(.id == $step_id2) | .description // \"\"" "$session_file")
      
      echo "Merging steps:"
      echo "  Step #$step_id1: $desc1"
      echo "  Step #$step_id2: $desc2"
      read -p "Continue? (y/N): " confirm
      
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 0
      fi
      
      # Merge descriptions
      local merged_desc="$desc1 + $desc2"
      
      # Update first step with merged description
      ${pkgs.jq}/bin/jq "(.steps[] | select(.id == $step_id1) | .description) = \"$merged_desc\"" \
        "$session_file" > "$session_file.tmp"
      
      # Delete second step
      ${pkgs.jq}/bin/jq "del(.steps[] | select(.id == $step_id2)) | .steps |= to_entries | .steps |= map(.value.id = .key + 1 | .value) | .stepCount = (.steps | length)" \
        "$session_file.tmp" > "$session_file"
      rm "$session_file.tmp"
      
      log "Merged steps #$step_id1 and #$step_id2 in $session_file"
      echo "Steps merged successfully"
    }
    
    # Split session
    split_session() {
      local session_file="$1"
      local split_at="$2"
      
      if [[ ! -f "$session_file" ]]; then
        echo "Error: Session file not found"
        return 1
      fi
      
      # Save undo state
      save_undo "$session_file"
      
      local session_dir=$(dirname "$session_file")
      local new_session_dir="''${session_dir}_part2"
      
      mkdir -p "$new_session_dir"
      
      # Split steps
      ${pkgs.jq}/bin/jq ".steps |= .[0:$split_at] | .stepCount = (.steps | length)" \
        "$session_file" > "$session_file.tmp"
      mv "$session_file.tmp" "$session_file"
      
      ${pkgs.jq}/bin/jq ".steps |= .[$split_at:] | .steps |= to_entries | .steps |= map(.value.id = .key + 1 | .value) | .stepCount = (.steps | length)" \
        "$session_file" > "$new_session_dir/metadata.json"
      
      log "Split session at step $split_at: $session_file -> $new_session_dir"
      echo "Session split successfully"
      echo "Part 1: $session_file"
      echo "Part 2: $new_session_dir/metadata.json"
    }
    
    # Undo last change
    undo() {
      local session_file="$1"
      
      # Find latest undo file
      local undo_file=$(ls -t "$UNDO_DIR"/$(basename "$session_file").*.undo 2>/dev/null | head -1)
      
      if [[ -z "$undo_file" ]]; then
        echo "No undo history available"
        return 1
      fi
      
      # Restore from undo
      cp "$undo_file" "$session_file"
      rm "$undo_file"
      
      log "Undo applied: restored from $undo_file"
      echo "Changes undone successfully"
    }
    
    # Batch delete steps
    batch_delete() {
      local session_file="$1"
      shift
      local step_ids=("$@")
      
      if [[ ! -f "$session_file" ]]; then
        echo "Error: Session file not found"
        return 1
      fi
      
      echo "Batch delete ${#step_ids[@]} steps"
      read -p "Continue? (y/N): " confirm
      
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 0
      fi
      
      # Save undo state
      save_undo "$session_file"
      
      # Delete all specified steps
      for step_id in "''${step_ids[@]}"; do
        ${pkgs.jq}/bin/jq "del(.steps[] | select(.id == $step_id))" \
          "$session_file" > "$session_file.tmp"
        mv "$session_file.tmp" "$session_file"
      done
      
      # Renumber remaining steps
      ${pkgs.jq}/bin/jq '.steps |= to_entries | .steps |= map(.value.id = .key + 1 | .value) | .stepCount = (.steps | length)' \
        "$session_file" > "$session_file.tmp"
      mv "$session_file.tmp" "$session_file"
      
      log "Batch deleted ${#step_ids[@]} steps from $session_file"
      echo "Batch delete completed"
    }
    
    # Command handling
    init_undo
    
    case "''${1:-list}" in
      list)
        if [[ -n "''${2:-}" ]]; then
          list_steps "$2"
        else
          list_sessions
        fi
        ;;
      edit)
        edit_step "''${2:?Session file required}" "''${3:?Step ID required}"
        ;;
      delete)
        delete_step "''${2:?Session file required}" "''${3:?Step ID required}"
        ;;
      reorder)
        reorder_step "''${2:?Session file required}" "''${3:?Step ID required}" "''${4:?New position required}"
        ;;
      merge)
        merge_steps "''${2:?Session file required}" "''${3:?Step ID 1 required}" "''${4:?Step ID 2 required}"
        ;;
      split)
        split_session "''${2:?Session file required}" "''${3:?Split position required}"
        ;;
      undo)
        undo "''${2:?Session file required}"
        ;;
      batch-delete)
        session_file="''${2:?Session file required}"
        shift 2
        batch_delete "$session_file" "$@"
        ;;
      *)
        echo "Usage: $0 {list|edit|delete|reorder|merge|split|undo|batch-delete} [args]"
        echo
        echo "Commands:"
        echo "  list [session]              - List sessions or steps in session"
        echo "  edit <session> <id>         - Edit step metadata"
        echo "  delete <session> <id>       - Delete a step"
        echo "  reorder <session> <id> <pos> - Reorder step to new position"
        echo "  merge <session> <id1> <id2> - Merge two consecutive steps"
        echo "  split <session> <pos>       - Split session at position"
        echo "  undo <session>              - Undo last change"
        echo "  batch-delete <session> <ids...> - Delete multiple steps"
        exit 1
        ;;
    esac
  '';
  
  # Integration functions
  integrationFunctions = ''
    # Step editing integration
    
    edit_current_session() {
      local session_file="$SESSION_DIR/metadata.json"
      chronicle-edit list "$session_file"
    }
    
    quick_delete_last_step() {
      local session_file="$SESSION_DIR/metadata.json"
      local last_step=$(${pkgs.jq}/bin/jq '.steps | length' "$session_file")
      chronicle-edit delete "$session_file" "$last_step"
    }
  '';
}
