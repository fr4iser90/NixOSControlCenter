{ lib, pkgs, cfg }:

let
  formatters = {
    html = import ../formatters/html.nix { inherit lib pkgs; };
    markdown = import ../formatters/markdown.nix { inherit lib pkgs; };
    json = import ../formatters/json.nix { inherit lib pkgs; };
    zip = import ../formatters/zip.nix { inherit lib pkgs; };
    pdf = import ../formatters/pdf.nix { inherit lib pkgs; };
  };
in
{
  # Main export function
  exportRecording = ''
    export_recording() {
      local session_dir="$1"
      local session_id=$(basename "$session_dir")

      case "${cfg.format}" in
        "html")
          ${formatters.html.exportHtml { sessionDir = "$session_dir"; sessionId = "$session_id"; }}
          export_html
          ;;
        "markdown")
          ${formatters.markdown.exportMarkdown { sessionDir = "$session_dir"; sessionId = "$session_id"; }}
          export_markdown
          ;;
        "json")
          ${formatters.json.exportJson { sessionDir = "$session_dir"; }}
          export_json
          ;;
        "pdf")
          ${formatters.pdf.exportPdf { sessionDir = "$session_dir"; sessionId = "$session_id"; }}
          export_pdf
          ;;
        "all")
          ${formatters.html.exportHtml { sessionDir = "$session_dir"; sessionId = "$session_id"; }}
          export_html
          ${formatters.markdown.exportMarkdown { sessionDir = "$session_dir"; sessionId = "$session_id"; }}
          export_markdown
          ${formatters.json.exportJson { sessionDir = "$session_dir"; }}
          export_json
          ${formatters.zip.exportZip { sessionDir = "$session_dir"; sessionId = "$session_id"; }}
          export_zip
          ${formatters.pdf.exportPdf { sessionDir = "$session_dir"; sessionId = "$session_id"; }}
          export_pdf
          ;;
        *)
          warn "Unknown export format: ${cfg.format}"
          ;;
      esac
    }
  '';
}
