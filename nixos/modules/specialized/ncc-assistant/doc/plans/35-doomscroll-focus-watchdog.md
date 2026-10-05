# Phase 35 — Doomscroll / focus watchdog

Status: **done**  
**Parent:** [roadmap.md](../roadmap.md)  
**Depends on:** companion (29–33), watchdogs (15), presence (7), prefs/capacity (34)

## Problem

Idle mode spends spare capacity when the user is *away*. The opposite failure
mode is **doomscrolling**: long stretches in Firefox/Chromium on social/video
feeds while the companion sits quiet.

## Product

```text
detect_desktop() → exactly one adapter
  hyprland         → hyprctl
  sway             → swaymsg
  plasma-wayland   → Firefox MPRIS (/shorts/ URL)
  plasma-x11 / x11 → xdotool
        │
        ▼
  Match apps + site titles /shorts/ URL (enums)
        │
   streak ≥ N min OR video_count ≥ max + cooldown ok
        │
        ├── nudge: notify-send
        ├── companion: raise Companion + dialog
        └── agent: fire watchdog doomscroll-threshold
```

## Preferences (`preferences.json`)

| Key | Type | Default |
|-----|------|---------|
| `doomscroll_enable` | bool | `false` |
| `doomscroll_after_min` | int 5–240 | `20` |
| `doomscroll_cooldown_min` | int 5–240 | `30` |
| `doomscroll_style` | `nudge` \| `companion` \| `agent` | `companion` |
| `doomscroll_apps` | enum checkboxes | `["firefox"]` |
| `doomscroll_match_mode` | `browser-sites` \| `listed-apps` | `browser-sites` |
| `doomscroll_site_tags` | multi-select enums | `["youtube-shorts"]` — drives **match needles + nft domains** |
| `doomscroll_lockout_min` | int 0–240 | `0` — timed nft block after interrupt |
| `doomscroll_pause_media` | bool | `true` — MPRIS Pause on intervene |
| `doomscroll_follow_target` | bool | `true` — jump to browser virtual desktop |
| `doomscroll_block_input` | bool | `false` — fullscreen overlay until dismiss |
| `doomscroll_inject_chat` | bool | `false` — also paste text into Companion chat |

**No freitext** for sites/apps/domains. Selecting **YouTube Shorts** alone is enough for `/shorts/` match **and** `youtube.com` net-block. Legacy `doomscroll_site_pack` migrates → `site_tags` on read.

## Surfaces

- Settings **Plugins** tab → Doomscroll prevention (was 4f; feature plugin)
- Companion timer (~15s) + tray timer
- CLI: `ncc ai focus status|tick|snooze`
- Watchdog event `doomscroll-threshold` (agent style)

## Non-goals

- Browser extension / DOM scraping
- Blocking network or killing Firefox
- Mobile / remote workers
- Interactive KWin `queryWindowInfo` (click-to-pick; not automatable)

## Plasma note

On Plasma Wayland, window titles via xdotool are often empty. For YouTube Shorts
we use Firefox MPRIS (`xesam:url` contains `/shorts/`) while PlaybackStatus is
Playing. Caption alone frequently has no word "Shorts".

## Acceptance

- [x] Off by default; enums/spinboxes only
- [x] After N matching minutes → notify and/or Companion pop-up
- [x] Snooze + presence paused skip intervene
- [x] Tests + gates green
