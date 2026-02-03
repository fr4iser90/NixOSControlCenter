{ lib, pkgs }:

{
  exportZip = { sessionDir, sessionId }: ''
    export_zip() {
      local session_dir="${sessionDir}"
      local zip_file="$session_dir/../${sessionId}.zip"

      cd "$(dirname "$session_dir")"
      ${pkgs.zip}/bin/zip -r "${sessionId}.zip" "$(basename "$session_dir")" > /dev/null 2>&1

      if [ -f "$zip_file" ]; then
        log "ZIP archive created: $zip_file"
      else
        warn "Failed to create ZIP archive"
      fi
    }
  '';
}
