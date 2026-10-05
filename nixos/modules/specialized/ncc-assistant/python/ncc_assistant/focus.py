"""Doomscroll / focus watchdog: active-window probe + intervene."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import Any

from .paths import focus_nudge_file, focus_state_file
from .preferences import (
    get_doomscroll_after_min,
    get_doomscroll_apps,
    get_doomscroll_block_domains,
    get_doomscroll_block_input,
    get_doomscroll_cooldown_min,
    get_doomscroll_enable,
    get_doomscroll_follow_target,
    get_doomscroll_inject_chat,
    get_doomscroll_lockout_min,
    get_doomscroll_match_mode,
    get_doomscroll_max_videos,
    get_doomscroll_pause_media,
    get_doomscroll_site_tags,
    get_doomscroll_style,
    needles_for_site_tags,
)

# Window class / app_id fragments (lowercase)
APP_CLASS_MAP: dict[str, tuple[str, ...]] = {
    "firefox": (
        "firefox",
        "firefox-esr",
        "org.mozilla.firefox",
        "librewolf",
        "navigator",
    ),
    "librewolf": ("librewolf", "firefox"),
    "brave": ("brave-browser", "brave", "brave-browser-stable"),
    "chromium": (
        "chromium",
        "chromium-browser",
        "google-chrome",
        "brave-browser",
        "brave",
        "vivaldi",
        "microsoft-edge",
        "chrome",
    ),
}

NUDGE_MESSAGES = (
    "Hey — you've been doomscrolling for a while. Close the tab and stretch.",
    "Focus check: social/video rabbit hole detected. Want a short break instead?",
    "Doomscroll interrupt: 20+ minutes in the feed. Pick one task and leave.",
    "YouTube Shorts binge check — enough clips. Close Shorts and do one real thing.",
)


def _ensure_hyprland_env() -> None:
    """If Cursor/SSH/scripts lack HIS, pick the newest Hyprland instance dir."""
    if os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "").strip():
        return
    bases: list[Path] = []
    xdg = os.environ.get("XDG_RUNTIME_DIR", "").strip()
    if xdg:
        bases.append(Path(xdg) / "hypr")
    bases.append(Path("/tmp/hypr"))
    newest: Path | None = None
    newest_mtime = -1.0
    for base in bases:
        if not base.is_dir():
            continue
        try:
            for child in base.iterdir():
                if not child.is_dir():
                    continue
                try:
                    mt = child.stat().st_mtime
                except OSError:
                    continue
                if mt > newest_mtime:
                    newest_mtime = mt
                    newest = child
        except OSError:
            continue
    if newest is not None:
        os.environ["HYPRLAND_INSTANCE_SIGNATURE"] = newest.name


def _run(cmd: list[str], *, timeout: float = 2.0) -> str | None:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return (proc.stdout or "").strip()


def _ensure_dbus_session() -> None:
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS", "").strip():
        xdg = os.environ.get("XDG_RUNTIME_DIR", "").strip() or f"/run/user/{os.getuid()}"
        bus = Path(xdg) / "bus"
        if bus.exists():
            os.environ["DBUS_SESSION_BUS_ADDRESS"] = f"unix:path={bus}"
    xdg = os.environ.get("XDG_RUNTIME_DIR", "").strip() or f"/run/user/{os.getuid()}"
    if not os.environ.get("WAYLAND_DISPLAY"):
        if (Path(xdg) / "wayland-0").exists():
            os.environ["WAYLAND_DISPLAY"] = "wayland-0"
    if not os.environ.get("DISPLAY"):
        os.environ["DISPLAY"] = ":0"
    if not os.environ.get("XAUTHORITY"):
        for cand in Path(xdg).glob("xauth_*"):
            if cand.is_file():
                os.environ["XAUTHORITY"] = str(cand)
                break


def _desktop_tokens() -> str:
    parts = [
        os.environ.get("XDG_CURRENT_DESKTOP", ""),
        os.environ.get("DESKTOP_SESSION", ""),
        os.environ.get("XDG_SESSION_DESKTOP", ""),
    ]
    return ":".join(parts).lower()


def _is_wayland() -> bool:
    if (os.environ.get("WAYLAND_DISPLAY") or "").strip():
        return True
    return (os.environ.get("XDG_SESSION_TYPE") or "").strip().lower() == "wayland"


def _kwin_on_bus() -> bool:
    """True if org.kde.KWin answers (Plasma session), without interactive query."""
    _ensure_dbus_session()
    if not shutil.which("qdbus"):
        return False
    raw = _run(["qdbus", "org.kde.KWin", "/KWin"], timeout=1.5)
    return bool(raw and "org.kde.KWin" in raw)


def detect_desktop() -> str:
    """
    Exclusive session id for window probing.
    One of: hyprland | sway | plasma-wayland | plasma-x11 | x11 | unknown.
    Never pick by "tool exists in PATH" (hyprctl is often installed on Plasma too).
    """
    tokens = _desktop_tokens()
    his = (os.environ.get("HYPRLAND_INSTANCE_SIGNATURE") or "").strip()
    sway = (os.environ.get("SWAYSOCK") or "").strip()

    if his or "hyprland" in tokens:
        return "hyprland"
    if sway or "sway" in tokens:
        return "sway"

    plasma = (
        "plasma" in tokens
        or "kde" in tokens
        or _kwin_on_bus()
    )
    if plasma:
        return "plasma-wayland" if _is_wayland() else "plasma-x11"

    if _is_wayland():
        return "unknown"
    if (os.environ.get("DISPLAY") or "").strip() or (
        os.environ.get("XDG_SESSION_TYPE") or ""
    ).strip().lower() == "x11":
        return "x11"
    return "unknown"


def _parse_qdbus_map(text: str) -> dict[str, str]:
    """Parse qdbus property dumps. Keys may contain colons (xesam:title)."""
    out: dict[str, str] = {}
    for line in (text or "").splitlines():
        if ": " in line:
            key, _, val = line.partition(": ")
        elif line.endswith(":"):
            key, val = line[:-1], ""
        else:
            continue
        key = key.strip()
        val = val.strip()
        if key:
            out[key] = val
    return out


def _firefox_mpris_tracks() -> list[dict[str, str]]:
    """Firefox MPRIS tracks (title + url). Shorts expose /shorts/<id> in xesam:url."""
    _ensure_dbus_session()
    if not shutil.which("qdbus") or not shutil.which("dbus-send"):
        return []
    names_raw = _run(
        [
            "dbus-send",
            "--session",
            "--print-reply",
            "--dest=org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus.ListNames",
        ],
        timeout=3.0,
    )
    if not names_raw:
        return []
    dests: list[str] = []
    for ln in names_raw.splitlines():
        if "org.mpris.MediaPlayer2.firefox" not in ln:
            continue
        start = ln.find('"')
        end = ln.rfind('"')
        if start >= 0 and end > start:
            dests.append(ln[start + 1 : end])
    tracks: list[dict[str, str]] = []
    for dest in dests:
        meta = _run(
            [
                "qdbus",
                dest,
                "/org/mpris/MediaPlayer2",
                "org.freedesktop.DBus.Properties.Get",
                "org.mpris.MediaPlayer2.Player",
                "Metadata",
            ],
            timeout=3.0,
        )
        status = _run(
            [
                "qdbus",
                dest,
                "/org/mpris/MediaPlayer2",
                "org.freedesktop.DBus.Properties.Get",
                "org.mpris.MediaPlayer2.Player",
                "PlaybackStatus",
            ],
            timeout=3.0,
        )
        if not meta:
            continue
        info = _parse_qdbus_map(meta)
        title = info.get("xesam:title") or ""
        url = info.get("xesam:url") or ""
        if title or url:
            tracks.append(
                {
                    "title": title,
                    "url": url,
                    "status": (status or "").strip(),
                    "dest": dest,
                }
            )
    return tracks


def _enrich_firefox_mpris(win: dict[str, str]) -> dict[str, str]:
    """Attach MPRIS url/title when the adapter already identified Firefox."""
    cls = (win.get("class") or "").lower()
    if "firefox" not in cls and "navigator" not in cls and "librewolf" not in cls:
        return win
    for tr in _firefox_mpris_tracks():
        url = tr.get("url") or ""
        if tr.get("status") == "Playing" or "/shorts/" in url:
            out = dict(win)
            out["url"] = url
            if tr.get("title"):
                out["mpris_title"] = tr["title"]
            return out
    return win


def _adapter_hyprland() -> dict[str, str] | None:
    if not shutil.which("hyprctl"):
        return None
    _ensure_hyprland_env()
    raw = _run(["hyprctl", "activewindow", "-j"])
    if not raw:
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    if not isinstance(data, dict) or not (data.get("class") or data.get("title")):
        return None
    win = {
        "class": str(data.get("class") or data.get("initialClass") or ""),
        "title": str(data.get("title") or ""),
        "source": "hyprland",
        "desktop": "hyprland",
    }
    return _enrich_firefox_mpris(win)


def _adapter_sway() -> dict[str, str] | None:
    if not shutil.which("swaymsg"):
        return None
    raw = _run(["swaymsg", "-t", "get_tree"])
    if not raw:
        return None
    try:
        tree = json.loads(raw)
    except json.JSONDecodeError:
        return None

    def _find(node: Any) -> dict[str, str] | None:
        if not isinstance(node, dict):
            return None
        if node.get("focused"):
            app = (
                node.get("app_id")
                or (node.get("window_properties") or {}).get("class")
                or ""
            )
            return {
                "class": str(app),
                "title": str(node.get("name") or ""),
                "source": "sway",
                "desktop": "sway",
            }
        for key in ("nodes", "floating_nodes"):
            for child in node.get(key) or []:
                hit = _find(child)
                if hit:
                    return hit
        return None

    hit = _find(tree)
    return _enrich_firefox_mpris(hit) if hit else None


def _adapter_xdotool(*, desktop: str) -> dict[str, str] | None:
    if not shutil.which("xdotool"):
        return None
    _ensure_dbus_session()
    wid = _run(["xdotool", "getactivewindow"])
    if not wid:
        return None
    title = _run(["xdotool", "getwindowname", wid]) or ""
    cls = _run(["xdotool", "getwindowclassname", wid]) or ""
    if not (title or cls):
        return None
    return _enrich_firefox_mpris(
        {"class": cls, "title": title, "source": "xdotool", "desktop": desktop}
    )


def _adapter_plasma_wayland() -> dict[str, str] | None:
    """
    Plasma Wayland only.

    Do not call hyprctl/xdotool here (wrong compositor / empty titles).
    KWin.queryWindowInfo is interactive (click-to-pick) — unusable for ticks.
    Firefox MPRIS is the proven non-interactive signal for Shorts (title + /shorts/ URL).
    """
    playing = [
        tr for tr in _firefox_mpris_tracks() if (tr.get("status") or "") == "Playing"
    ]
    if not playing:
        return None
    pick_sorted = sorted(
        playing,
        key=lambda t: (0 if "/shorts/" in (t.get("url") or "") else 1),
    )
    tr = pick_sorted[0]
    title = tr.get("title") or ""
    url = tr.get("url") or ""
    if not (title or url):
        return None
    return {
        "class": "firefox",
        "title": title,
        "url": url,
        "source": "plasma-mpris",
        "desktop": "plasma-wayland",
        "mpris_status": "Playing",
    }


def get_active_window() -> dict[str, str] | None:
    """
    Active window via exactly one desktop adapter (no cross-compositor fallback chain).
    """
    desktop = detect_desktop()
    if desktop == "hyprland":
        return _adapter_hyprland()
    if desktop == "sway":
        return _adapter_sway()
    if desktop == "plasma-wayland":
        return _adapter_plasma_wayland()
    if desktop == "plasma-x11":
        return _adapter_xdotool(desktop="plasma-x11")
    if desktop == "x11":
        return _adapter_xdotool(desktop="x11")
    return None


def _apps_match(win_class: str, apps: list[str]) -> bool:
    c = (win_class or "").lower()
    if not c:
        return False
    selected = apps or ["firefox"]
    if "browsers" in selected:
        selected = list({*selected, "firefox", "chromium", "brave", "librewolf"})
    for app in selected:
        if app == "browsers":
            continue
        frags = APP_CLASS_MAP.get(app, (app,))
        if any(f in c for f in frags):
            return True
    return False


def _sites_match(title: str, *, url: str = "") -> bool:
    """Match against needles derived from selected site-tag enums."""
    t = (title or "").lower()
    u = (url or "").lower()
    tags = get_doomscroll_site_tags()
    # youtube-shorts: prefer URL /shorts/ (Plasma captions often omit the word)
    if "youtube-shorts" in tags:
        if "/shorts/" in u or "youtube.com/shorts" in u:
            return True
        if ("shorts" in t or "#shorts" in t) and (
            "youtube" in t or "youtube" in u or "youtu.be" in t
        ):
            return True
    needles = needles_for_site_tags(tags)
    return any(n in t or n in u for n in needles)


def is_doomscroll_window(win: dict[str, str] | None) -> bool:
    if not win:
        return False
    apps = get_doomscroll_apps()
    if not _apps_match(win.get("class") or "", apps):
        return False
    mode = get_doomscroll_match_mode()
    if mode == "listed-apps":
        return True
    title = win.get("title") or win.get("mpris_title") or ""
    return _sites_match(title, url=win.get("url") or "")


def _empty_state() -> dict[str, Any]:
    return {
        "streak_sec": 0.0,
        "video_count": 0,
        "last_title": "",
        "last_tick": None,
        "last_match": False,
        "last_intervene": 0.0,
        "snooze_until": 0.0,
        "lockout_until": 0.0,
        "window": None,
    }


def _load_state() -> dict[str, Any]:
    path = focus_state_file()
    if not path.is_file():
        return _empty_state()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return _empty_state()
    return data if isinstance(data, dict) else _empty_state()


def _save_state(state: dict[str, Any]) -> None:
    path = focus_state_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(state, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def snooze(minutes: int = 30) -> dict[str, Any]:
    state = _load_state()
    mins = max(1, min(int(minutes), 240))
    state["snooze_until"] = time.time() + mins * 60
    state["streak_sec"] = 0.0
    state["video_count"] = 0
    state["last_title"] = ""
    state["lockout_until"] = 0.0
    _save_state(state)
    clear_pending_nudge()
    try:
        from .focus_netblock import clear_net_block

        clear_net_block()
    except Exception:
        pass
    return status()


def clear_snooze() -> dict[str, Any]:
    state = _load_state()
    state["snooze_until"] = 0.0
    _save_state(state)
    return status()


def clear_pending_nudge() -> None:
    path = focus_nudge_file()
    try:
        if path.is_file():
            path.unlink()
    except OSError:
        pass


def write_pending_nudge(payload: dict[str, Any]) -> None:
    path = focus_nudge_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def consume_pending_nudge() -> dict[str, Any] | None:
    path = focus_nudge_file()
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        clear_pending_nudge()
        return None
    clear_pending_nudge()
    return data if isinstance(data, dict) else None


def peek_pending_nudge() -> dict[str, Any] | None:
    path = focus_nudge_file()
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def status() -> dict[str, Any]:
    state = _load_state()
    desktop = detect_desktop()
    win = get_active_window()
    thresh = float(get_doomscroll_after_min()) * 60.0
    streak = float(state.get("streak_sec") or 0.0)
    videos = int(state.get("video_count") or 0)
    hint = None
    lockout_until = float(state.get("lockout_until") or 0.0)
    lockout_left = max(0, int(lockout_until - time.time()))
    if not win or not (win.get("class") or win.get("title") or win.get("url")):
        if desktop == "plasma-wayland":
            hint = (
                "Plasma Wayland adapter: no Playing Firefox MPRIS track. "
                "Play a YouTube Short in Firefox, then re-check."
            )
        elif desktop == "hyprland":
            hint = "Hyprland adapter: hyprctl activewindow empty. Focus a window and re-check."
        elif desktop == "sway":
            hint = "Sway adapter: no focused node from swaymsg."
        elif desktop in ("plasma-x11", "x11"):
            hint = "X11 adapter: xdotool getactivewindow empty."
        else:
            hint = f"No window adapter for desktop={desktop!r}."
    elif not is_doomscroll_window(win) and get_doomscroll_enable():
        hint = (
            "Window seen but not matching selected site tags / apps."
        )
    return {
        "enable": get_doomscroll_enable(),
        "style": get_doomscroll_style(),
        "after_min": get_doomscroll_after_min(),
        "max_videos": get_doomscroll_max_videos(),
        "cooldown_min": get_doomscroll_cooldown_min(),
        "lockout_min": get_doomscroll_lockout_min(),
        "lockout_remaining_sec": lockout_left,
        "apps": get_doomscroll_apps(),
        "match_mode": get_doomscroll_match_mode(),
        "site_tags": get_doomscroll_site_tags(),
        "block_domains": get_doomscroll_block_domains(),
        "desktop": desktop,
        "adapter": (win or {}).get("source") or desktop,
        "matching_now": is_doomscroll_window(win),
        "pause_media": get_doomscroll_pause_media(),
        "block_input": get_doomscroll_block_input(),
        "follow_target": get_doomscroll_follow_target(),
        "inject_chat": get_doomscroll_inject_chat(),
        "streak_sec": streak,
        "streak_min": round(streak / 60.0, 2),
        "video_count": videos,
        "threshold_sec": thresh,
        "metrics": {
            "time": (
                "Companion/tray ticks ~every 15s. While the active window matches, "
                "streak_sec += delta (capped 120s/tick). Interrupt when "
                f"streak_sec ≥ {get_doomscroll_after_min()}×60."
            ),
            "videos": (
                "Each tick compares clip id = MPRIS url || mpris_title || window title. "
                "When it changes while matching, video_count += 1. Interrupt when "
                f"video_count ≥ {get_doomscroll_max_videos()} (0 = video metric off). "
                "Whichever hits first (time OR videos) intervenes."
            ),
            "net_block": (
                "After interrupt, if lockout_min>0: nft sinkhole domains derived "
                "from selected site tags (YouTube Shorts → youtube.com, …). "
                "No separate block list."
            ),
        },
        "window": win,
        "snooze_until": float(state.get("snooze_until") or 0.0),
        "last_intervene": float(state.get("last_intervene") or 0.0),
        "pending_nudge": peek_pending_nudge() is not None,
        "hint": hint,
    }


def _pick_message(streak_sec: float, *, videos: int = 0, reason: str = "time") -> str:
    mins = max(1, int(streak_sec // 60))
    if reason == "videos" and videos > 0:
        return (
            f"YouTube Shorts binge: ~{videos} clips in a row. "
            "Close Shorts and do one real thing."
        )
    idx = mins % len(NUDGE_MESSAGES)
    base = NUDGE_MESSAGES[idx]
    return re.sub(r"\d+\+?\s*minutes?", f"{mins} minutes", base, count=1)


def _intervene(
    state: dict[str, Any],
    win: dict[str, str],
    streak: float,
    *,
    videos: int = 0,
    reason: str = "time",
) -> dict[str, Any]:
    style = get_doomscroll_style()
    msg = _pick_message(streak, videos=videos, reason=reason)
    payload = {
        "ts": time.time(),
        "message": msg,
        "style": style,
        "streak_sec": streak,
        "video_count": videos,
        "reason": reason,
        "window": win,
    }
    write_pending_nudge(payload)
    state["last_intervene"] = time.time()
    state["streak_sec"] = 0.0
    state["video_count"] = 0
    state["last_title"] = ""
    lockout_m = get_doomscroll_lockout_min()
    if lockout_m > 0:
        state["lockout_until"] = time.time() + lockout_m * 60.0
    else:
        state["lockout_until"] = 0.0
    _save_state(state)

    actions: dict[str, Any] = {}
    try:
        from .focus_actions import apply_intervene_side_effects

        actions = apply_intervene_side_effects()
    except Exception as exc:  # noqa: BLE001
        actions = {"error": str(exc)}

    # REAL domain sinkhole (nft via ncc-focus-netblock) — not soft overlay.
    if lockout_m > 0:
        try:
            from .focus_netblock import apply_net_block

            actions["net_block"] = apply_net_block(minutes=lockout_m)
        except Exception as exc:  # noqa: BLE001
            actions["net_block"] = {"ok": False, "error": str(exc)}

    notified = False
    try:
        from .notifications import notify_send

        notified = bool(
            notify_send(
                "NCC · Doomscroll interrupt",
                msg,
                urgency="critical",
                timeout_ms=12_000,
            )
        )
    except Exception:
        notified = False

    agent_result = None
    if style == "agent":
        try:
            from .watchdogs import ensure_doomscroll_watchdog, fire_event

            ensure_doomscroll_watchdog(enable_for_agent=True)
            agent_result = fire_event("doomscroll-threshold", force=False)
        except Exception as exc:  # noqa: BLE001
            agent_result = {"ok": False, "error": str(exc)}

    return {
        "ok": True,
        "intervened": True,
        "style": style,
        "message": msg,
        "reason": reason,
        "notified": notified,
        "actions": actions,
        "agent": agent_result,
        "window": win,
        "streak_sec": streak,
        "video_count": videos,
    }


def tick(*, force_window: dict[str, str] | None = None) -> dict[str, Any]:
    """
    Advance focus streak + Shorts video counter. Call from Companion/Tray (~15–30s).
    Intervenes when time ≥ after_min OR (max_videos>0 and title-changes ≥ max).
    """
    now = time.time()
    state = _load_state()
    if not get_doomscroll_enable():
        return {"ok": True, "intervened": False, "reason": "disabled", **status()}

    snooze_until = float(state.get("snooze_until") or 0.0)
    if now < snooze_until:
        return {
            "ok": True,
            "intervened": False,
            "reason": "snoozed",
            "snooze_remaining_sec": int(snooze_until - now),
            **status(),
        }

    try:
        from .presence import get_presence

        if get_presence().state == "paused":
            return {"ok": True, "intervened": False, "reason": "paused", **status()}
    except Exception:
        pass

    win = force_window if force_window is not None else get_active_window()
    matching = is_doomscroll_window(win)
    last_tick = state.get("last_tick")
    delta = 0.0
    if isinstance(last_tick, (int, float)) and last_tick > 0:
        delta = max(0.0, min(now - float(last_tick), 120.0))

    streak = float(state.get("streak_sec") or 0.0)
    videos = int(state.get("video_count") or 0)
    last_title = str(state.get("last_title") or "")
    # Prefer MPRIS URL for clip identity (Plasma Shorts caption often stays put).
    win_d = win or {}
    clip_id = str(win_d.get("url") or win_d.get("mpris_title") or win_d.get("title") or "")

    if matching:
        streak += delta if delta > 0 else 0.0
        if delta == 0 and streak == 0:
            streak = 1.0
        # Count distinct clip ids (url/title) as Shorts / clip transitions.
        if clip_id and clip_id != last_title:
            videos = videos + 1 if last_title else max(videos, 1)
            last_title = clip_id
    else:
        streak = 0.0
        videos = 0
        last_title = ""

    state["last_tick"] = now
    state["last_match"] = matching
    state["streak_sec"] = streak
    state["video_count"] = videos
    state["last_title"] = last_title
    state["window"] = win

    # Clear nft block when lockout window ends.
    prev_lockout = float(state.get("lockout_until") or 0.0)
    if prev_lockout > 0 and now >= prev_lockout:
        state["lockout_until"] = 0.0
        try:
            from .focus_netblock import clear_net_block

            clear_net_block()
        except Exception:
            pass

    _save_state(state)

    cooldown = float(get_doomscroll_cooldown_min()) * 60.0
    last_i = float(state.get("last_intervene") or 0.0)
    thresh = float(get_doomscroll_after_min()) * 60.0
    max_vids = get_doomscroll_max_videos()
    cooled = (now - last_i) >= cooldown

    if matching and cooled:
        if max_vids > 0 and videos >= max_vids:
            return _intervene(
                state,
                win or {"class": "", "title": ""},
                streak,
                videos=videos,
                reason="videos",
            )
        if streak >= thresh:
            return _intervene(
                state,
                win or {"class": "", "title": ""},
                streak,
                videos=videos,
                reason="time",
            )

    out = status()
    out.update({"ok": True, "intervened": False, "matching": matching})
    return out
