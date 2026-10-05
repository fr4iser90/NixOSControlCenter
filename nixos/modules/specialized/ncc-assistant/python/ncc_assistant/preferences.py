"""User preferences (last model / provider) under ~/.config/ncc-assistant/."""

from __future__ import annotations

import json
import os
from typing import Any

from .paths import preferences_file


def load_preferences() -> dict[str, Any]:
    path = preferences_file()
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def save_preferences(data: dict[str, Any]) -> None:
    path = preferences_file()
    path.parent.mkdir(parents=True, exist_ok=True)
    merged = load_preferences()
    merged.update({k: v for k, v in data.items() if v is not None})
    path.write_text(
        json.dumps(merged, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    try:
        os.chmod(path, 0o600)
    except OSError:
        pass


def get_last_model() -> str | None:
    raw = load_preferences().get("last_model")
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return None


def get_last_provider_id() -> str | None:
    raw = load_preferences().get("last_provider_id")
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return None


def set_last_model(model: str | None) -> None:
    if model:
        save_preferences({"last_model": model})


def set_last_provider(provider_id: str | None, endpoint: str | None = None) -> None:
    payload: dict[str, Any] = {}
    if provider_id:
        payload["last_provider_id"] = provider_id
    if endpoint:
        payload["last_endpoint"] = endpoint
    if payload:
        save_preferences(payload)


def get_trace_density() -> str:
    raw = load_preferences().get("trace_density")
    if isinstance(raw, str) and raw.strip().lower() in ("compact", "comfortable"):
        return raw.strip().lower()
    return "comfortable"


def set_trace_density(density: str) -> None:
    d = (density or "").strip().lower()
    if d in ("compact", "comfortable"):
        save_preferences({"trace_density": d})


def get_expand_thinking_while_streaming() -> bool:
    return bool(load_preferences().get("expand_thinking_while_streaming"))


def set_expand_thinking_while_streaming(enabled: bool) -> None:
    save_preferences({"expand_thinking_while_streaming": bool(enabled)})


def get_default_harness_mode() -> str:
    raw = load_preferences().get("harness_mode")
    if isinstance(raw, str) and raw.strip().lower() in (
        "auto",
        "native",
        "qwen",
        "dsh",
    ):
        return raw.strip().lower()
    return "auto"


def set_default_harness_mode(mode: str) -> None:
    m = (mode or "").strip().lower()
    if m in ("auto", "native", "qwen", "dsh"):
        save_preferences({"harness_mode": m})


def get_active_workspace_id() -> str | None:
    raw = load_preferences().get("active_workspace_id")
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return None


def set_active_workspace_id(workspace_id: str | None) -> None:
    if workspace_id and str(workspace_id).strip():
        save_preferences({"active_workspace_id": str(workspace_id).strip()})
    else:
        save_preferences({"active_workspace_id": ""})


DEFAULT_LLM_TIMEOUT_SEC = 300
DEFAULT_LLM_RETRIES = 1


def get_llm_timeout_sec() -> int:
    """Wall-clock HTTP timeout for chat/completions (seconds)."""
    raw = load_preferences().get("llm_timeout_sec", DEFAULT_LLM_TIMEOUT_SEC)
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_LLM_TIMEOUT_SEC
    return max(30, min(n, 3600))


def set_llm_timeout_sec(sec: int) -> None:
    try:
        n = int(sec)
    except (TypeError, ValueError):
        return
    save_preferences({"llm_timeout_sec": max(30, min(n, 3600))})


def get_llm_retries() -> int:
    """Extra attempts after a transient failure (0 = try once)."""
    raw = load_preferences().get("llm_retries", DEFAULT_LLM_RETRIES)
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_LLM_RETRIES
    return max(0, min(n, 5))


def set_llm_retries(retries: int) -> None:
    try:
        n = int(retries)
    except (TypeError, ValueError):
        return
    save_preferences({"llm_retries": max(0, min(n, 5))})


# --- Phase 34: capacity / idle / daily workflows ---

IDLE_MODES = ("off", "schedules", "schedules+backlog")
DEFAULT_MAX_CONCURRENCY = 2
DEFAULT_IDLE_AFTER_MIN = 15
DEFAULT_IDLE_MAX_JOBS = 1
DEFAULT_DAILY_DIGEST_CAL = "*-*-* 08:30:00"


def get_max_concurrency() -> int:
    raw = load_preferences().get("max_concurrency", DEFAULT_MAX_CONCURRENCY)
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_MAX_CONCURRENCY
    return max(1, min(n, 8))


def set_max_concurrency(n: int) -> None:
    try:
        v = int(n)
    except (TypeError, ValueError):
        return
    save_preferences({"max_concurrency": max(1, min(v, 8))})


def get_idle_mode() -> str:
    raw = load_preferences().get("idle_mode", "off")
    if isinstance(raw, str) and raw.strip().lower() in IDLE_MODES:
        return raw.strip().lower()
    return "off"


def set_idle_mode(mode: str) -> None:
    m = (mode or "").strip().lower()
    if m in IDLE_MODES:
        save_preferences({"idle_mode": m})


def get_idle_after_min() -> int:
    raw = load_preferences().get("idle_after_min", DEFAULT_IDLE_AFTER_MIN)
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_IDLE_AFTER_MIN
    return max(5, min(n, 240))


def set_idle_after_min(n: int) -> None:
    try:
        v = int(n)
    except (TypeError, ValueError):
        return
    save_preferences({"idle_after_min": max(5, min(v, 240))})


def get_idle_max_jobs() -> int:
    raw = load_preferences().get("idle_max_jobs", DEFAULT_IDLE_MAX_JOBS)
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_IDLE_MAX_JOBS
    return max(1, min(n, 4))


def set_idle_max_jobs(n: int) -> None:
    try:
        v = int(n)
    except (TypeError, ValueError):
        return
    save_preferences({"idle_max_jobs": max(1, min(v, 4))})


def get_daily_digest_enable() -> bool:
    raw = load_preferences().get("daily_digest_enable")
    if raw is None:
        return True
    return bool(raw)


def set_daily_digest_enable(enabled: bool) -> None:
    save_preferences({"daily_digest_enable": bool(enabled)})


def get_daily_digest_on_calendar() -> str:
    raw = load_preferences().get("daily_digest_on_calendar", DEFAULT_DAILY_DIGEST_CAL)
    if isinstance(raw, str) and raw.strip():
        return raw.strip()
    return DEFAULT_DAILY_DIGEST_CAL


def set_daily_digest_on_calendar(cal: str) -> None:
    c = (cal or "").strip()
    if c:
        save_preferences({"daily_digest_on_calendar": c})


def get_workflow_providers() -> list[str]:
    raw = load_preferences().get("workflow_providers", ["github"])
    if isinstance(raw, list):
        out = [str(x).strip().lower() for x in raw if str(x).strip()]
        return out or ["github"]
    return ["github"]


def set_workflow_providers(providers: list[str]) -> None:
    allowed = {"github"}
    cleaned = [p for p in (str(x).strip().lower() for x in providers) if p in allowed]
    save_preferences({"workflow_providers": cleaned or ["github"]})


# Morning Brief plugin (sources / auto-refresh / once-per-day latch)
MORNING_BRIEF_SOURCES = ("github-prs", "github-issues", "tasks", "roadmap")


def get_morning_brief_sources() -> list[str]:
    raw = load_preferences().get("morning_brief_sources")
    if isinstance(raw, list) and raw:
        out = [
            s
            for s in (str(x).strip().lower() for x in raw)
            if s in MORNING_BRIEF_SOURCES
        ]
        if out:
            return out
    return list(MORNING_BRIEF_SOURCES)


def set_morning_brief_sources(sources: list[str] | str) -> None:
    if isinstance(sources, str):
        parts = [p.strip().lower() for p in sources.replace(";", ",").split(",")]
    else:
        parts = [str(x).strip().lower() for x in sources]
    cleaned = [s for s in parts if s in MORNING_BRIEF_SOURCES]
    save_preferences(
        {"morning_brief_sources": cleaned or list(MORNING_BRIEF_SOURCES)}
    )


def get_morning_brief_auto_refresh() -> bool:
    return bool(load_preferences().get("morning_brief_auto_refresh", True))


def set_morning_brief_auto_refresh(enabled: bool) -> None:
    save_preferences({"morning_brief_auto_refresh": bool(enabled)})


def get_morning_brief_last_fired() -> str:
    raw = load_preferences().get("morning_brief_last_fired", "")
    return str(raw).strip() if raw else ""


def set_morning_brief_last_fired(day: str) -> None:
    save_preferences({"morning_brief_last_fired": str(day or "").strip()})


# --- Phase 35: doomscroll / focus watchdog ---

DOOMSCROLL_STYLES = ("nudge", "companion", "agent")
DOOMSCROLL_MATCH_MODES = ("browser-sites", "listed-apps")

# Multi-select enums only — no freestyle site/app lists in the primary UI.
DOOMSCROLL_APP_CHOICES = ("firefox", "chromium", "brave", "librewolf", "browsers")

DOOMSCROLL_SITE_TAGS: tuple[str, ...] = (
    "youtube-shorts",
    "youtube",
    "reddit",
    "tiktok",
    "instagram",
    "twitter",
    "facebook",
    "twitch",
    "linkedin",
    "threads",
    "netflix",
    "disney",
    "prime-video",
)

# label, title/url needles, hosts/nft domains (one selection → match + block)
DOOMSCROLL_SITE_TAG_META: dict[str, dict[str, Any]] = {
    "youtube-shorts": {
        "label": "YouTube Shorts",
        "needles": ("/shorts/", "youtube.com/shorts", "#shorts"),
        # Site + CDN/API — video bytes ride googlevideo, not only youtube.com.
        "domains": (
            "youtube.com",
            "www.youtube.com",
            "m.youtube.com",
            "youtu.be",
            "youtube-nocookie.com",
            "www.youtube-nocookie.com",
            "googlevideo.com",
            "youtubei.googleapis.com",
            "ytimg.com",
            "i.ytimg.com",
            "s.ytimg.com",
        ),
    },
    "youtube": {
        "label": "YouTube",
        "needles": ("youtube", "youtu.be"),
        "domains": (
            "youtube.com",
            "www.youtube.com",
            "m.youtube.com",
            "youtu.be",
            "youtube-nocookie.com",
            "www.youtube-nocookie.com",
            "googlevideo.com",
            "youtubei.googleapis.com",
            "ytimg.com",
            "i.ytimg.com",
            "s.ytimg.com",
        ),
    },
    "reddit": {
        "label": "Reddit",
        "needles": ("reddit",),
        "domains": ("reddit.com", "www.reddit.com", "old.reddit.com"),
    },
    "tiktok": {
        "label": "TikTok",
        "needles": ("tiktok",),
        "domains": ("tiktok.com", "www.tiktok.com", "vm.tiktok.com"),
    },
    "instagram": {
        "label": "Instagram",
        "needles": ("instagram",),
        "domains": ("instagram.com", "www.instagram.com"),
    },
    "twitter": {
        "label": "Twitter / X",
        "needles": ("twitter", "x.com"),
        "domains": ("twitter.com", "www.twitter.com", "x.com", "www.x.com"),
    },
    "facebook": {
        "label": "Facebook",
        "needles": ("facebook",),
        "domains": ("facebook.com", "www.facebook.com", "fb.com"),
    },
    "twitch": {
        "label": "Twitch",
        "needles": ("twitch",),
        "domains": ("twitch.tv", "www.twitch.tv"),
    },
    "linkedin": {
        "label": "LinkedIn",
        "needles": ("linkedin",),
        "domains": ("linkedin.com", "www.linkedin.com"),
    },
    "threads": {
        "label": "Threads",
        "needles": ("threads",),
        "domains": ("threads.net", "www.threads.net"),
    },
    "netflix": {
        "label": "Netflix",
        "needles": ("netflix",),
        "domains": ("netflix.com", "www.netflix.com"),
    },
    "disney": {
        "label": "Disney+",
        "needles": ("disney",),
        "domains": ("disneyplus.com", "www.disneyplus.com"),
    },
    "prime-video": {
        "label": "Prime Video",
        "needles": ("prime video", "primevideo"),
        "domains": ("primevideo.com", "www.primevideo.com"),
    },
}

# Legacy single-pack keys (migrated → site_tags on read)
DOOMSCROLL_SITE_PACKS = (
    "social",
    "video",
    "social+video",
    "youtube-shorts",
    "any-browser",
    "custom",
)

DEFAULT_DOOMSCROLL_AFTER_MIN = 20
DEFAULT_DOOMSCROLL_COOLDOWN_MIN = 30
DEFAULT_DOOMSCROLL_MAX_VIDEOS = 0
DEFAULT_DOOMSCROLL_LOCKOUT_MIN = 0


def _parse_csv_list(raw: Any, *, lower: bool = True) -> list[str]:
    """Split comma/newline/semicolon list into cleaned tokens."""
    if raw is None:
        return []
    if isinstance(raw, list):
        parts = [str(x) for x in raw]
    else:
        text = str(raw).replace(";", ",").replace("\n", ",")
        parts = text.split(",")
    out: list[str] = []
    seen: set[str] = set()
    for p in parts:
        tok = p.strip()
        if lower:
            tok = tok.lower()
        if not tok or tok in seen:
            continue
        seen.add(tok)
        out.append(tok)
    return out


def _site_tags_from_legacy_pack(pack: str) -> list[str]:
    p = (pack or "").strip().lower()
    social = ["reddit", "tiktok", "instagram", "twitter", "facebook", "linkedin", "threads"]
    video = ["youtube", "twitch", "netflix", "disney", "prime-video"]
    if p == "youtube-shorts":
        return ["youtube-shorts"]
    if p == "social":
        return social
    if p == "video":
        return video
    if p == "social+video":
        return social + video
    if p == "any-browser":
        return list(DOOMSCROLL_SITE_TAGS)
    return ["youtube-shorts"]


def get_doomscroll_enable() -> bool:
    return bool(load_preferences().get("doomscroll_enable", False))


def set_doomscroll_enable(enabled: bool) -> None:
    save_preferences({"doomscroll_enable": bool(enabled)})


def get_doomscroll_after_min() -> int:
    raw = load_preferences().get("doomscroll_after_min", DEFAULT_DOOMSCROLL_AFTER_MIN)
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_DOOMSCROLL_AFTER_MIN
    return max(1, min(n, 240))


def set_doomscroll_after_min(n: int) -> None:
    try:
        v = int(n)
    except (TypeError, ValueError):
        return
    save_preferences({"doomscroll_after_min": max(1, min(v, 240))})


def get_doomscroll_max_videos() -> int:
    """Title-change count threshold (0 = ignore video count)."""
    raw = load_preferences().get("doomscroll_max_videos", DEFAULT_DOOMSCROLL_MAX_VIDEOS)
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_DOOMSCROLL_MAX_VIDEOS
    return max(0, min(n, 50))


def set_doomscroll_max_videos(n: int) -> None:
    try:
        v = int(n)
    except (TypeError, ValueError):
        return
    save_preferences({"doomscroll_max_videos": max(0, min(v, 50))})


def get_doomscroll_cooldown_min() -> int:
    raw = load_preferences().get(
        "doomscroll_cooldown_min", DEFAULT_DOOMSCROLL_COOLDOWN_MIN
    )
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_DOOMSCROLL_COOLDOWN_MIN
    return max(5, min(n, 240))


def set_doomscroll_cooldown_min(n: int) -> None:
    try:
        v = int(n)
    except (TypeError, ValueError):
        return
    save_preferences({"doomscroll_cooldown_min": max(5, min(v, 240))})


def get_doomscroll_style() -> str:
    raw = load_preferences().get("doomscroll_style", "companion")
    if isinstance(raw, str) and raw.strip().lower() in DOOMSCROLL_STYLES:
        return raw.strip().lower()
    return "companion"


def set_doomscroll_style(style: str) -> None:
    s = (style or "").strip().lower()
    if s in DOOMSCROLL_STYLES:
        save_preferences({"doomscroll_style": s})


def get_doomscroll_match_mode() -> str:
    raw = load_preferences().get("doomscroll_match_mode", "browser-sites")
    if isinstance(raw, str) and raw.strip().lower() in DOOMSCROLL_MATCH_MODES:
        return raw.strip().lower()
    return "browser-sites"


def set_doomscroll_match_mode(mode: str) -> None:
    m = (mode or "").strip().lower()
    if m in DOOMSCROLL_MATCH_MODES:
        save_preferences({"doomscroll_match_mode": m})


def get_doomscroll_site_pack() -> str:
    """Legacy single pack — prefer get_doomscroll_site_tags()."""
    tags = get_doomscroll_site_tags()
    if tags == ["youtube-shorts"]:
        return "youtube-shorts"
    return "custom"


def set_doomscroll_site_pack(pack: str) -> None:
    """Legacy writer — converts pack → site_tags enums."""
    set_doomscroll_site_tags(_site_tags_from_legacy_pack(pack))


def get_doomscroll_site_tags() -> list[str]:
    """Multi-select site enums (match + net-block domains derived from these)."""
    raw = load_preferences().get("doomscroll_site_tags")
    if isinstance(raw, list) and raw:
        out = [t for t in _parse_csv_list(raw, lower=True) if t in DOOMSCROLL_SITE_TAG_META]
        if out:
            return out
    # Migrate legacy site_pack
    pack = load_preferences().get("doomscroll_site_pack", "youtube-shorts")
    if isinstance(pack, str):
        return _site_tags_from_legacy_pack(pack)
    return ["youtube-shorts"]


def set_doomscroll_site_tags(tags: list[str] | str) -> None:
    cleaned = [t for t in _parse_csv_list(tags, lower=True) if t in DOOMSCROLL_SITE_TAG_META]
    save_preferences({"doomscroll_site_tags": cleaned or ["youtube-shorts"]})


def get_doomscroll_apps() -> list[str]:
    """App enums only (firefox / chromium / brave / librewolf / browsers)."""
    raw = load_preferences().get("doomscroll_apps", ["firefox"])
    out = [a for a in _parse_csv_list(raw, lower=True) if a in DOOMSCROLL_APP_CHOICES]
    return out or ["firefox"]


def set_doomscroll_apps(apps: list[str] | str) -> None:
    cleaned = [a for a in _parse_csv_list(apps, lower=True) if a in DOOMSCROLL_APP_CHOICES]
    save_preferences({"doomscroll_apps": cleaned or ["firefox"]})


def get_doomscroll_site_extras() -> list[str]:
    """Deprecated — always empty (enums only)."""
    return []


def set_doomscroll_site_extras(items: list[str] | str) -> None:
    """Deprecated no-op — site needles come from site_tags enums."""
    del items


def get_doomscroll_lockout_min() -> int:
    """After intervene: REAL net block duration in minutes (0 = no timed nft block)."""
    raw = load_preferences().get("doomscroll_lockout_min", DEFAULT_DOOMSCROLL_LOCKOUT_MIN)
    try:
        n = int(raw)
    except (TypeError, ValueError):
        return DEFAULT_DOOMSCROLL_LOCKOUT_MIN
    return max(0, min(n, 240))


def set_doomscroll_lockout_min(n: int) -> None:
    try:
        v = int(n)
    except (TypeError, ValueError):
        return
    save_preferences({"doomscroll_lockout_min": max(0, min(v, 240))})


def get_doomscroll_netblock_granted() -> bool:
    """User opted in to timed nft net-block (Grant / auth-check)."""
    return bool(load_preferences().get("doomscroll_netblock_granted", False))


def set_doomscroll_netblock_granted(granted: bool) -> None:
    save_preferences({"doomscroll_netblock_granted": bool(granted)})


def domains_for_site_tags(tags: list[str] | None = None) -> list[str]:
    """Hosts/nft domains derived from selected site enums (no separate block list)."""
    selected = tags if tags is not None else get_doomscroll_site_tags()
    out: list[str] = []
    seen: set[str] = set()
    for tag in selected:
        meta = DOOMSCROLL_SITE_TAG_META.get(tag) or {}
        for d in meta.get("domains") or ():
            ds = str(d).lower()
            if ds and ds not in seen:
                seen.add(ds)
                out.append(ds)
    return out


def needles_for_site_tags(tags: list[str] | None = None) -> list[str]:
    selected = tags if tags is not None else get_doomscroll_site_tags()
    out: list[str] = []
    seen: set[str] = set()
    for tag in selected:
        meta = DOOMSCROLL_SITE_TAG_META.get(tag) or {}
        for n in meta.get("needles") or ():
            ns = str(n).lower()
            if ns and ns not in seen:
                seen.add(ns)
                out.append(ns)
    return out


def get_doomscroll_block_domains() -> list[str]:
    """Always derived from site_tags — selecting Shorts/YouTube/… is enough."""
    return domains_for_site_tags()


def set_doomscroll_block_domains(items: list[str] | str) -> None:
    """Deprecated no-op — domains follow site_tags."""
    del items


def get_doomscroll_pause_media() -> bool:
    """Pause Firefox/Chromium MPRIS media on intervene (default on)."""
    return bool(load_preferences().get("doomscroll_pause_media", True))


def set_doomscroll_pause_media(enabled: bool) -> None:
    save_preferences({"doomscroll_pause_media": bool(enabled)})


def get_doomscroll_block_input() -> bool:
    """Fullscreen overlay until dismiss — blocks clicks through to the browser."""
    return bool(load_preferences().get("doomscroll_block_input", False))


def set_doomscroll_block_input(enabled: bool) -> None:
    save_preferences({"doomscroll_block_input": bool(enabled)})


def get_doomscroll_follow_target() -> bool:
    """Jump to the browser's virtual desktop before showing the interrupt."""
    return bool(load_preferences().get("doomscroll_follow_target", True))


def set_doomscroll_follow_target(enabled: bool) -> None:
    save_preferences({"doomscroll_follow_target": bool(enabled)})


def get_doomscroll_inject_chat() -> bool:
    """Also paste the interrupt text into the Companion chat bubble (default off)."""
    return bool(load_preferences().get("doomscroll_inject_chat", False))


def set_doomscroll_inject_chat(enabled: bool) -> None:
    save_preferences({"doomscroll_inject_chat": bool(enabled)})


def apply_startup_preferences(settings: Any) -> Any:
    """Apply last provider / model from preferences (Nix model env wins if set)."""
    from dataclasses import replace

    from .auth import with_cached_credentials
    from .providers import apply_provider_settings, ensure_seeded, get_provider

    ensure_seeded()
    nix_model = os.environ.get("NCC_ASSISTANT_MODEL", "").strip()
    model = settings.model
    if not nix_model:
        last = get_last_model()
        if last:
            model = last

    pid = get_last_provider_id()
    if pid:
        prov = get_provider(pid)
        if prov is not None:
            settings = apply_provider_settings(settings, prov)
            settings = replace(settings, model=model)
            return with_cached_credentials(settings)

    if model != settings.model:
        settings = replace(settings, model=model)
    return with_cached_credentials(settings)
