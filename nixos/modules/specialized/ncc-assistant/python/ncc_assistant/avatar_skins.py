"""Pluggable companion avatar skins (painted default · image · frame sequence)."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from .paths import avatar_skins_dir, preferences_file
import json


def list_skins() -> list[dict[str, str]]:
    """Discover skin folders under avatar-skins/ plus built-in painted."""
    out = [{"id": "painted", "label": "Painted (default)", "kind": "painted"}]
    root = avatar_skins_dir()
    for child in sorted(root.iterdir() if root.is_dir() else []):
        if not child.is_dir():
            continue
        kind = "frames" if any(child.glob("*.png")) or any(child.glob("*.webp")) else "image"
        # Live2D export: folder with model3.json → treat as frames dir if pngs present
        if (child / "model3.json").is_file() or (child / "model.json").is_file():
            kind = "live2d_export"
        out.append({"id": child.name, "label": child.name, "kind": kind, "path": str(child)})
    env = (os.environ.get("NCC_ASSISTANT_AVATAR_SKIN") or "").strip()
    if env and not any(s["id"] == env for s in out):
        p = Path(env).expanduser()
        if p.is_dir():
            out.append({"id": p.name, "label": f"env:{p.name}", "kind": "frames", "path": str(p)})
    return out


def get_active_skin_id() -> str:
    env = (os.environ.get("NCC_ASSISTANT_AVATAR_SKIN") or "").strip()
    if env:
        return Path(env).name if "/" in env or env.startswith(".") else env
    path = preferences_file()
    if path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            raw = data.get("avatar_skin")
            if isinstance(raw, str) and raw.strip():
                return raw.strip()
        except (OSError, json.JSONDecodeError):
            pass
    return "painted"


def set_active_skin_id(skin_id: str) -> None:
    from .preferences import load_preferences, save_preferences

    save_preferences({**load_preferences(), "avatar_skin": skin_id})


def resolve_skin(skin_id: str | None = None) -> dict[str, Any]:
    sid = skin_id or get_active_skin_id()
    for s in list_skins():
        if s["id"] == sid:
            return s
    return {"id": "painted", "label": "Painted (default)", "kind": "painted"}


def frame_paths(skin: dict[str, Any], state: str) -> list[Path]:
    """Return ordered image paths for a mood (idle/thinking/speaking/…)."""
    root = Path(skin.get("path") or "")
    if not root.is_dir():
        return []
    # Prefer state-named files: idle.png, thinking.png, …
    for ext in (".png", ".webp", ".jpg"):
        named = root / f"{state}{ext}"
        if named.is_file():
            return [named]
    # Subfolder per state
    sub = root / state
    if sub.is_dir():
        frames = sorted(
            list(sub.glob("*.png")) + list(sub.glob("*.webp")) + list(sub.glob("*.jpg"))
        )
        if frames:
            return frames
    # Fallback: any frames in root (Live2D PNG export / sprite dump)
    frames = sorted(
        list(root.glob("*.png")) + list(root.glob("*.webp")) + list(root.glob("*.jpg"))
    )
    return frames[:24]
