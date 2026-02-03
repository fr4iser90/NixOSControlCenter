{ lib, pkgs }:

{
  exportJson = { sessionDir }: ''
    export_json() {
      local session_dir="${sessionDir}"
      local json_file="$session_dir/full_report.json"

      # Combine session and steps data
      local session_json="$session_dir/session.json"
      local steps_dir="$session_dir/steps"

      # Start with session data (without closing brace)
      ${pkgs.jq}/bin/jq '. | del(.steps)' "$session_json" > "$json_file.tmp"

      # Add steps array
      echo ',' >> "$json_file.tmp"
      echo '"steps": [' >> "$json_file.tmp"

      local first=true
      if [ -d "$steps_dir" ]; then
        for step_file in "$steps_dir"/step_*.json; do
          if [ -f "$step_file" ]; then
            if [ "$first" = "true" ]; then
              first=false
            else
              echo ',' >> "$json_file.tmp"
            fi
            cat "$step_file" >> "$json_file.tmp"
          fi
        done
      fi

      echo ']' >> "$json_file.tmp"
      echo '}' >> "$json_file.tmp"

      # Pretty print
      ${pkgs.jq}/bin/jq '.' "$json_file.tmp" > "$json_file"
      rm "$json_file.tmp"

      log "JSON report generated: $json_file"
    }
  '';
}
