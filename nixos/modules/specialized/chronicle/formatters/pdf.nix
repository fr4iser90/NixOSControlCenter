{ lib, pkgs }:

{
  exportPdf = { sessionDir, sessionId }: ''
    export_pdf() {
      local session_dir="${sessionDir}"
      local html_file="$session_dir/report.html"
      local pdf_file="$session_dir/report.pdf"

      # Check if HTML report exists, generate if not
      if [ ! -f "$html_file" ]; then
        log "HTML report not found, generating first..."
        export_html
      fi

      # Try wkhtmltopdf first (better quality)
      if command -v wkhtmltopdf &> /dev/null; then
        log "Generating PDF with wkhtmltopdf..."
        wkhtmltopdf \
          --enable-local-file-access \
          --page-size A4 \
          --margin-top 15mm \
          --margin-bottom 15mm \
          --margin-left 15mm \
          --margin-right 15mm \
          --encoding UTF-8 \
          --enable-javascript \
          --javascript-delay 1000 \
          --no-stop-slow-scripts \
          --print-media-type \
          "$html_file" "$pdf_file" 2>&1 | while read -r line; do
            log "wkhtmltopdf: $line"
          done
        
        if [ -f "$pdf_file" ]; then
          log "PDF report generated: $pdf_file"
          ${pkgs.libnotify}/bin/notify-send "Step Recorder" "PDF export complete: $pdf_file" --urgency=low
          return 0
        fi
      fi

      # Fallback to weasyprint
      if command -v weasyprint &> /dev/null; then
        log "Generating PDF with weasyprint..."
        weasyprint "$html_file" "$pdf_file" 2>&1 | while read -r line; do
          log "weasyprint: $line"
        done
        
        if [ -f "$pdf_file" ]; then
          log "PDF report generated: $pdf_file"
          ${pkgs.libnotify}/bin/notify-send "Step Recorder" "PDF export complete: $pdf_file" --urgency=low
          return 0
        fi
      fi

      # Fallback to chromium/chrome headless
      local browser=""
      for cmd in chromium google-chrome chrome; do
        if command -v "$cmd" &> /dev/null; then
          browser="$cmd"
          break
        fi
      done

      if [ -n "$browser" ]; then
        log "Generating PDF with $browser headless..."
        "$browser" --headless --disable-gpu --print-to-pdf="$pdf_file" \
          --no-pdf-header-footer \
          --print-to-pdf-no-header \
          "file://$html_file" 2>&1 | while read -r line; do
            log "chromium: $line"
          done
        
        if [ -f "$pdf_file" ]; then
          log "PDF report generated: $pdf_file"
          ${pkgs.libnotify}/bin/notify-send "Step Recorder" "PDF export complete: $pdf_file" --urgency=low
          return 0
        fi
      fi

      # No PDF tool available
      log_error "PDF export failed: No suitable PDF generator found (wkhtmltopdf, weasyprint, or chromium)"
      ${pkgs.libnotify}/bin/notify-send "Step Recorder" "PDF export failed: No PDF generator available" --urgency=critical
      return 1
    }
  '';
}
