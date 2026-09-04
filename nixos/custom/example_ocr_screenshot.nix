# Example: OCR from region screenshot or from an image file.
# Picks capture tools from session (Wayland/X11) and desktop (KDE, GNOME, wlroots, …).
# Enable by importing this module from your NixOS configuration (like other example_*.nix files).
{ config, lib, pkgs, ... }:

let
  tesseractOcr = pkgs.tesseract.override { enableLanguages = [ "deu" "eng" ]; };

  ocrScreenshot = pkgs.writeShellScriptBin "ocr-screenshot" ''
    set -euo pipefail

    TESS="${tesseractOcr}/bin/tesseract"
    OCR_LANG="''${OCR_LANG:-deu+eng}"
    VERBOSE="''${OCR_SHOT_DEBUG:-0}"

    usage() {
      cat <<'EOF'
Usage: ocr-screenshot [options] [image.png]
  Region capture then OCR, or OCR an existing image.

  Session/desktop are detected (XDG_SESSION_TYPE, WAYLAND_DISPLAY, XDG_CURRENT_DESKTOP,
  SWAYSOCK, HYPRLAND_INSTANCE_SIGNATURE). Capture backend:

  • X11 session          → maim (region)
  • Wayland + KDE/KWin   → spectacle -r -b
  • Wayland + GNOME/Mutter → gnome-screenshot -a
  • Wayland + wlroots (Sway, Hyprland, …) → grim + slurp
  • Wayland + unknown    → grim+slurp, then spectacle, then gnome-screenshot

Options:
  -c, --clipboard   Copy recognized text to clipboard (wl-copy / xclip)
  -v, --verbose     Print detected session/desktop and capture attempts (stderr)
  -h, --help        Show this help

Environment:
  OCR_LANG          Tesseract languages, default: deu+eng
  OCR_PSM           Optional page-segmentation mode, e.g. 6 (single block) or 4 (single column).
                    Dense terminal tables still will not match the on-screen layout — OCR is linear text.
  OCR_SHOT_DEBUG=1  Same as -v

Examples:
  ocr-screenshot -v -c
  OCR_PSM=6 ocr-screenshot -c
  ocr-screenshot ~/Screenshots/x.png
EOF
    }

    COPY=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        -c|--clipboard) COPY=1; shift ;;
        -v|--verbose) VERBOSE=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) break ;;
      esac
    done

    vlog() {
      [[ "$VERBOSE" == 1 ]] || return 0
      printf '[ocr-screenshot] %s\n' "$*" >&2
    }

    run_ocr() {
      local input="$1"
      local text
      if [[ -n "''${OCR_PSM:-}" ]]; then
        text="$("$TESS" "$input" stdout --psm "''${OCR_PSM}" -l "$OCR_LANG" 2>/dev/null || true)"
      else
        text="$("$TESS" "$input" stdout -l "$OCR_LANG" 2>/dev/null || true)"
      fi
      if [[ -z "$text" ]]; then
        echo "[ocr-screenshot] No text recognized (or tesseract failed)." >&2
        return 1
      fi
      printf '%s\n' "$text"
      if [[ -n "$COPY" ]]; then
        if command -v wl-copy >/dev/null 2>&1 && [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
          printf '%s' "$text" | wl-copy
        elif command -v xclip >/dev/null 2>&1 && [[ -n "''${DISPLAY:-}" ]]; then
          printf '%s' "$text" | xclip -selection clipboard
        else
          echo "[ocr-screenshot] Clipboard requested but neither wl-copy nor xclip is available." >&2
        fi
      fi
    }

    # Returns: wayland | x11 | unknown
    detect_session_kind() {
      local st="''${XDG_SESSION_TYPE:-}"
      case "''${st,,}" in
        wayland) echo wayland; return ;;
        x11|xorg) echo x11; return ;;
        tty)
          if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
            echo wayland
          elif [[ -n "''${DISPLAY:-}" ]]; then
            echo x11
          else
            echo unknown
          fi
          return
          ;;
      esac
      if [[ -n "''${WAYLAND_DISPLAY:-}" ]]; then
        echo wayland
      elif [[ -n "''${DISPLAY:-}" ]]; then
        echo x11
      else
        echo unknown
      fi
    }

    # Returns: kde | gnome | wlroots | other
    detect_desktop_kind() {
      if [[ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        echo wlroots
        return
      fi
      if [[ -n "''${SWAYSOCK:-}" ]]; then
        echo wlroots
        return
      fi
      local d="''${XDG_CURRENT_DESKTOP:-}"
      d="''${d,,}"
      local s="''${DESKTOP_SESSION:-}"
      s="''${s,,}"
      local c="''${XDG_SESSION_DESKTOP:-}"
      c="''${c,,}"

      if [[ "$d" == *kde* ]] || [[ "$d" == *plasma* ]] || [[ "$s" == *plasma* ]] || [[ "$c" == *kde* ]] || [[ "$c" == *plasma* ]]; then
        echo kde
        return
      fi
      if [[ "$d" == *gnome* ]] || [[ "$d" == *budgie* ]] || [[ "$d" == *ubuntu*gnome* ]] || [[ "$s" == *gnome* ]]; then
        echo gnome
        return
      fi
      if [[ "$d" == *sway* ]] || [[ "$d" == *hyprland* ]] || [[ "$d" == *dwl* ]] || [[ "$d" == *wayfire* ]] || [[ "$d" == *river* ]] || [[ "$d" == *labwc* ]] || [[ "$d" == *niri* ]]; then
        echo wlroots
        return
      fi
      echo other
    }

    try_grim_slurp() {
      local tmp="$1"
      command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1 || return 1
      local geom
      geom="$(slurp 2>/dev/null || true)"
      [[ -z "$geom" ]] && { vlog "grim+slurp: no region"; return 1; }
      if grim -g "$geom" "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        vlog "capture ok: grim+slurp"
        return 0
      fi
      vlog "grim+slurp: grim failed or empty"
      return 1
    }

    # KWin: region capture often fails with -r -b -o together; Qt may print QThreadStorage warnings
    # and still write the file, or exit non-zero despite success. Success = non-empty PNG.
    try_spectacle() {
      local tmp="$1"
      command -v spectacle >/dev/null 2>&1 || return 1
      local variant
      # -o is documented for background mode; try -b before -r / -r -b first (Plasma 5/6 differ).
      for variant in \
        '-b -r -o' \
        '-r -b -o' \
        '-r -o'
      do
        rm -f "$tmp"
        # shellcheck disable=SC2086
        if spectacle $variant "$tmp" 2>/dev/null; then
          :
        fi
        if [[ -s "$tmp" ]]; then
          vlog "capture ok: spectacle (KDE) args: $variant"
          return 0
        fi
      done
      vlog "spectacle: cancelled or no image written"
      return 1
    }

    try_gnome_screenshot() {
      local tmp="$1"
      command -v gnome-screenshot >/dev/null 2>&1 || return 1
      rm -f "$tmp"
      gnome-screenshot -a -f "$tmp" 2>/dev/null || true
      if [[ -s "$tmp" ]]; then
        vlog "capture ok: gnome-screenshot"
        return 0
      fi
      vlog "gnome-screenshot: cancelled or failed"
      return 1
    }

    # Works on many Wayland setups (including KDE) via xdg-desktop-portal.
    try_flameshot() {
      local tmp="$1"
      command -v flameshot >/dev/null 2>&1 || return 1
      rm -f "$tmp"
      flameshot gui -p "$tmp" 2>/dev/null || true
      if [[ -s "$tmp" ]]; then
        vlog "capture ok: flameshot"
        return 0
      fi
      vlog "flameshot: cancelled or failed"
      return 1
    }

    capture_x11() {
      local tmp="$1"
      command -v maim >/dev/null 2>&1 || { echo "[ocr-screenshot] X11: maim not installed." >&2; return 1; }
      if maim -s "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        vlog "capture ok: maim (X11)"
        return 0
      fi
      echo "[ocr-screenshot] X11: selection cancelled or maim failed." >&2
      return 1
    }

    # Wayland: order depends on detected desktop; always ends with generic fallbacks.
    capture_wayland() {
      local tmp="$1"
      local kind
      kind="$(detect_desktop_kind)"
      vlog "xdg_session_type=''${XDG_SESSION_TYPE:-} wayland_display=''${WAYLAND_DISPLAY:-} display=''${DISPLAY:-}"
      vlog "xdg_current_desktop=''${XDG_CURRENT_DESKTOP:-} desktop_kind=$kind"

      case "$kind" in
        kde)
          try_spectacle "$tmp" && return 0
          vlog "KDE: spectacle failed, trying portal-friendly fallbacks (grim does not work on KWin)"
          try_gnome_screenshot "$tmp" && return 0
          try_grim_slurp "$tmp" && return 0
          try_flameshot "$tmp" && return 0
          echo "[ocr-screenshot] KDE/Wayland: all capture tools failed. Cancelled? Try: spectacle -b -r -o /tmp/t.png or install flameshot." >&2
          return 1
          ;;
        gnome)
          try_gnome_screenshot "$tmp" && return 0
          try_grim_slurp "$tmp" && return 0
          try_spectacle "$tmp" && return 0
          return 1
          ;;
        wlroots)
          try_grim_slurp "$tmp" && return 0
          try_spectacle "$tmp" && return 0
          try_gnome_screenshot "$tmp" && return 0
          return 1
          ;;
        other)
          try_grim_slurp "$tmp" && return 0
          try_spectacle "$tmp" && return 0
          try_gnome_screenshot "$tmp" && return 0
          return 1
          ;;
      esac
    }

    if [[ $# -ge 1 && -f "$1" ]]; then
      run_ocr "$1"
      exit 0
    fi

    if [[ $# -ge 1 ]]; then
      echo "[ocr-screenshot] Not a file: $1" >&2
      exit 1
    fi

    tmp="$(mktemp -t ocr-screenshot.XXXXXX.png)"
    cleanup() { rm -f "$tmp"; }
    trap cleanup EXIT

    sk="$(detect_session_kind)"
    vlog "session_kind=$sk (xdg_session_type=''${XDG_SESSION_TYPE:-})"

    case "$sk" in
      x11)
        capture_x11 "$tmp" || exit 1
        ;;
      wayland)
        capture_wayland "$tmp" || {
          echo "[ocr-screenshot] All Wayland capture methods failed. Install spectacle (KDE), gnome-screenshot (GNOME), or grim+slurp (wlroots)." >&2
          exit 1
        }
        ;;
      unknown)
        echo "[ocr-screenshot] No display session (set DISPLAY or WAYLAND_DISPLAY, or run from a graphical session)." >&2
        exit 1
        ;;
    esac

    run_ocr "$tmp"
  '';
in
{
  environment.systemPackages = [
    tesseractOcr
    ocrScreenshot
    pkgs.grim
    pkgs.slurp
    pkgs.maim
    pkgs.wl-clipboard
    pkgs.xclip
    pkgs.kdePackages.spectacle
    pkgs.gnome-screenshot
    pkgs.flameshot
  ];
}
