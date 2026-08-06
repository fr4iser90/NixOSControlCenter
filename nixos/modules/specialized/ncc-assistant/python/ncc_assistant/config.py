"""Runtime settings from environment (injected by Nix wrappers)."""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import urlparse


def _env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in ("1", "true", "yes", "on")


def _env_optional_str(name: str) -> str | None:
    raw = os.environ.get(name)
    if raw is None:
        return None
    raw = raw.strip()
    if not raw or raw.lower() in ("null", "none", ""):
        return None
    return raw


def _env_optional_int(name: str) -> int | None:
    raw = _env_optional_str(name)
    if raw is None:
        return None
    return int(raw)


def _env_optional_float(name: str) -> float | None:
    raw = _env_optional_str(name)
    if raw is None:
        return None
    return float(raw)


def normalize_endpoint(url: str) -> str:
    """Ensure OpenAI-compatible base ends with /v1 when only a host was given."""
    u = url.strip().rstrip("/")
    parsed = urlparse(u)
    if parsed.path in ("", "/"):
        return f"{u}/v1"
    return u


def resolve_api(api: str | None, provider: str | None) -> str:
    """Map api / legacy provider → openai-compatible | anthropic."""
    raw = (api or provider or "openai-compatible").strip().lower()
    if raw in ("ollama", "openai", "openai-compatible", "compatible"):
        return "openai-compatible"
    if raw == "anthropic":
        return "anthropic"
    return raw


@dataclass(frozen=True)
class Settings:
    root: Path
    knowledge_root: Path
    prompts_root: Path
    config_bin: str
    api: str
    model: str | None
    endpoint: str
    api_key: str | None
    api_header_name: str | None
    max_tokens: int | None
    temperature: float | None
    allow_write: bool
    mcp_allow_write: bool
    allow_rebuild: bool
    client_mode: str  # "chat" | "mcp"
    nixos_dir: str

    @property
    def provider(self) -> str:
        """Backward-compatible alias used in UI strings."""
        return self.api

    @property
    def writes_enabled(self) -> bool:
        if self.client_mode == "mcp":
            return self.mcp_allow_write
        return self.allow_write

    @staticmethod
    def _load_api_key() -> str | None:
        # Env overrides file (local debugging). Never store keys in systemConfig.
        for name in (
            "NCC_ASSISTANT_API_KEY",
            "OPENAI_API_KEY",
            "ANTHROPIC_API_KEY",
        ):
            raw = os.environ.get(name)
            if raw and raw.strip():
                return raw.strip().strip('"').strip("'")

        key_file = os.environ.get("NCC_ASSISTANT_API_KEY_FILE")
        if key_file and Path(key_file).is_file():
            return (
                Path(key_file)
                .read_text(encoding="utf-8")
                .strip()
                .strip('"')
                .strip("'")
            )
        return None

    @classmethod
    def from_env(cls, client_mode: str = "chat") -> "Settings":
        root = Path(os.environ.get("NCC_ASSISTANT_ROOT", ".")).resolve()
        knowledge = Path(
            os.environ.get("NCC_KNOWLEDGE_ROOT", str(root / "knowledge"))
        ).resolve()
        prompts = Path(
            os.environ.get("NCC_PROMPTS_ROOT", str(root / "prompts"))
        ).resolve()

        header = os.environ.get("NCC_ASSISTANT_API_HEADER_NAME")
        if header is not None:
            header = header.strip() or None

        api = resolve_api(
            _env_optional_str("NCC_ASSISTANT_API"),
            _env_optional_str("NCC_ASSISTANT_PROVIDER"),
        )
        endpoint = normalize_endpoint(
            os.environ.get("NCC_ASSISTANT_ENDPOINT", "http://localhost:11434/v1")
        )

        return cls(
            root=root,
            knowledge_root=knowledge,
            prompts_root=prompts,
            config_bin=os.environ.get(
                "NCC_ASSISTANT_CONFIG_BIN", "ncc-assistant-config"
            ),
            api=api,
            model=_env_optional_str("NCC_ASSISTANT_MODEL"),
            endpoint=endpoint,
            api_key=cls._load_api_key(),
            api_header_name=header,
            max_tokens=_env_optional_int("NCC_ASSISTANT_MAX_TOKENS"),
            temperature=_env_optional_float("NCC_ASSISTANT_TEMPERATURE"),
            allow_write=_env_bool("NCC_ASSISTANT_ALLOW_WRITE", True),
            mcp_allow_write=_env_bool("NCC_ASSISTANT_MCP_ALLOW_WRITE", False),
            allow_rebuild=_env_bool("NCC_ASSISTANT_ALLOW_REBUILD", False),
            client_mode=client_mode,
            nixos_dir=os.environ.get("NIXOS_DIR", "/etc/nixos"),
        )

    def load_system_prompt(self) -> str:
        path = self.prompts_root / "system.md"
        if path.is_file():
            return path.read_text(encoding="utf-8")
        return (
            "You are the NCC assistant. Use tools to read config and knowledge "
            "before changing anything."
        )
