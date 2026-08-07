"""Shared tool runtime for MCP and built-in chat."""

from __future__ import annotations

import difflib
import json
import os
import re
import subprocess
import time
from pathlib import Path
from typing import Any, Callable

from .config import Settings

TOOL_DEFINITIONS: list[dict[str, Any]] = [
    {
        "name": "list_modules",
        "description": (
            "List known NCC modules from the knowledge registries "
            "(core + optional)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {
                    "type": "string",
                    "description": "Optional substring filter on module name/path",
                }
            },
        },
    },
    {
        "name": "read_module_config",
        "description": (
            "Read the active systemConfig leaf for a module path "
            "(e.g. core/base/packages or modules/specialized/chronicle)."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "module_path": {
                    "type": "string",
                    "description": "Module path relative to systemConfig root",
                }
            },
            "required": ["module_path"],
        },
    },
    {
        "name": "search_knowledge",
        "description": (
            "Search the NCC knowledge pack (skills, domains, contexts, "
            "module registries) by keyword."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string"},
                "limit": {"type": "integer", "default": 8},
            },
            "required": ["query"],
        },
    },
    {
        "name": "explain_path",
        "description": (
            "Explain a module path using knowledge registries and optional "
            "on-disk hints under the assistant knowledge root."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "module_path": {"type": "string"},
            },
            "required": ["module_path"],
        },
    },
    {
        "name": "propose_config_patch",
        "description": (
            "Show a unified diff between current module config and a proposed "
            "Nix attrset. Does NOT write."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "module_path": {"type": "string"},
                "proposed_nix": {
                    "type": "string",
                    "description": "Proposed Nix attrset fragment",
                },
            },
            "required": ["module_path", "proposed_nix"],
        },
    },
    {
        "name": "apply_module_config",
        "description": (
            "Write a Nix attrset fragment to a module config via the NCC "
            "config facade. Requires confirm=true and write permission."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "module_path": {"type": "string"},
                "content_nix": {"type": "string"},
                "confirm": {
                    "type": "boolean",
                    "description": "Must be true to actually write",
                },
            },
            "required": ["module_path", "content_nix", "confirm"],
        },
    },
    {
        "name": "validate_config",
        "description": (
            "Validate a Nix attrset fragment parses, or validate the current "
            "module leaf if content_nix is omitted."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "module_path": {"type": "string"},
                "content_nix": {"type": "string"},
            },
        },
    },
    {
        "name": "apply_system",
        "description": (
            "Run `ncc system build switch` after config changes. Requires "
            "allowRebuild and confirm exactly equal to CONFIRM."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "confirm": {
                    "type": "string",
                    "description": 'Must be the string "CONFIRM"',
                },
                "hostname": {
                    "type": "string",
                    "description": "Optional flake hostname attribute",
                },
            },
            "required": ["confirm"],
        },
    },
    {
        "name": "run_preflight",
        "description": (
            "Run preflight checks before a system rebuild. "
            "Returns ok if prebuild script exists and succeeds, or stub ok if not present."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "config_health_report",
        "description": (
            "Generate a configuration health report using knowledge registries "
            "and optional nix-instantiate validation."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {},
        },
    },
    {
        "name": "memory_list",
        "description": "List persistent memory notes for context.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "tag": {"type": "string", "description": "Optional tag filter"},
                "limit": {"type": "integer", "default": 20},
            },
        },
    },
    {
        "name": "memory_add",
        "description": "Add a note to persistent memory.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "content": {"type": "string", "description": "Note content"},
                "tags": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Optional tags",
                },
            },
            "required": ["content"],
        },
    },
    {
        "name": "memory_forget",
        "description": "Remove a note from memory by ID.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "note_id": {"type": "string", "description": "ID of note to forget"},
            },
            "required": ["note_id"],
        },
    },
    {
        "name": "list_config_backups",
        "description": "List available NixOS configuration backups from /var/backup/nixos if present.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "default": 20},
            },
        },
    },
    {
        "name": "list_boot_generations",
        "description": "List NixOS system generations for rollback guidance.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "default": 20},
            },
        },
    },
    {
        "name": "disk_nix_report",
        "description": (
            "Probe root filesystem and /nix/store usage (no LLM). "
            "Returns percentages, sizes, generation count, and threshold flag."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "threshold_pct": {
                    "type": "number",
                    "description": "Root usage %% that marks over_threshold (default 85)",
                    "default": 85,
                },
            },
        },
    },
    {
        "name": "restore_config_backup",
        "description": (
            "Load a config backup for guided restore. Requires confirm=true. "
            "Does not auto-apply a full monolith."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "backup_path": {"type": "string"},
                "confirm": {"type": "boolean"},
            },
            "required": ["backup_path", "confirm"],
        },
    },
    {
        "name": "agent_finish",
        "description": (
            "Signal that the agent has completed its goal or cannot proceed. "
            "Only used in agent mode."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "summary": {"type": "string", "description": "Summary of outcome"},
                "success": {"type": "boolean", "description": "Whether goal was achieved"},
            },
            "required": ["summary", "success"],
        },
    },
]
MUTATING_TOOLS = {"apply_module_config", "apply_system", "restore_config_backup"}


class ToolRuntime:
    def __init__(
        self,
        settings: Settings,
        confirm_hook: Callable[[dict[str, Any]], bool] | None = None,
        *,
        dry_run: bool = False,
    ):
        self.settings = settings
        self.confirm_hook = confirm_hook
        self._index: dict[str, Any] | None = None
        self._dry_run = dry_run
        self._call_counts: dict[str, int] = {}
        self._mcp_pool: Any = None

    @property
    def dry_run(self) -> bool:
        return self._dry_run

    @dry_run.setter
    def dry_run(self, value: bool) -> None:
        self._dry_run = value

    def _get_mcp_pool(self) -> Any:
        if self._mcp_pool is None:
            from .mcp_client import get_mcp_pool
            self._mcp_pool = get_mcp_pool()
        return self._mcp_pool

    # --- facade helpers -------------------------------------------------

    def _config_cmd(self, *args: str, input_text: str | None = None) -> subprocess.CompletedProcess[str]:
        cmd = [self.settings.config_bin, *args]
        env = os.environ.copy()
        env["NIXOS_DIR"] = self.settings.nixos_dir
        return subprocess.run(
            cmd,
            input=input_text,
            capture_output=True,
            text=True,
            env=env,
            check=False,
        )

    def read_module_config(self, module_path: str) -> dict[str, Any]:
        path = self._normalize_path(module_path)
        proc = self._config_cmd("read", path)
        if proc.returncode != 0:
            return {
                "ok": False,
                "error": proc.stderr.strip() or proc.stdout.strip() or "read failed",
                "module_path": path,
            }
        return {"ok": True, "module_path": path, "content": proc.stdout}

    def apply_module_config(
        self, module_path: str, content_nix: str, confirm: bool = False
    ) -> dict[str, Any]:
        path = self._normalize_path(module_path)
        if not self.settings.writes_enabled:
            return {
                "ok": False,
                "error": (
                    "Writes disabled for this client "
                    f"(mode={self.settings.client_mode}). "
                    "Enable allowWrite / mcpAllowWrite in module config."
                ),
            }
        if not confirm:
            proposal = self.propose_config_patch(path, content_nix)
            return {
                "ok": False,
                "error": "confirm=true required to write. Diff preview included.",
                "preview": proposal,
            }

        current = self.read_module_config(path)
        proc = self._config_cmd("write", path, input_text=content_nix)
        if proc.returncode != 0:
            return {
                "ok": False,
                "error": proc.stderr.strip() or proc.stdout.strip() or "write failed",
            }
        return {
            "ok": True,
            "module_path": path,
            "before": current.get("content", ""),
            "after": content_nix,
            "message": "Config written via ncc_write_module_config. Rebuild not applied.",
        }

    # --- knowledge ------------------------------------------------------

    def _load_index(self) -> dict[str, Any]:
        if self._index is not None:
            return self._index
        index_path = self.settings.knowledge_root / "index.json"
        if not index_path.is_file():
            self._index = {}
            return self._index
        self._index = json.loads(index_path.read_text(encoding="utf-8"))
        return self._index

    def _iter_knowledge_files(self) -> list[tuple[str, Path]]:
        index = self._load_index()
        root = self.settings.knowledge_root
        entries: list[tuple[str, Path]] = []
        for section in ("skills", "contexts", "domains", "modules"):
            for item in index.get(section, []) or []:
                rel = item.get("file")
                if not rel:
                    continue
                path = root / rel
                if path.is_file():
                    entries.append((item.get("id", rel), path))
        # Always include registries if present even without index
        for extra in (
            "modules/core-registry.json",
            "modules/optional-registry.json",
        ):
            path = root / extra
            if path.is_file() and not any(p == path for _, p in entries):
                entries.append((extra, path))
        return entries

    def list_modules(self, query: str | None = None) -> dict[str, Any]:
        modules: list[dict[str, str]] = []
        root = self.settings.knowledge_root
        for name in ("core-registry.json", "optional-registry.json"):
            path = root / "modules" / name
            if not path.is_file():
                continue
            data = json.loads(path.read_text(encoding="utf-8"))
            kind = "core" if "core" in name else "optional"
            self._walk_registry(data, kind, modules)
        if query:
            q = query.lower()
            modules = [
                m
                for m in modules
                if q in m["name"].lower()
                or q in m.get("path", "").lower()
                or q in m.get("domain", "").lower()
            ]
        modules.sort(key=lambda m: (m.get("domain", ""), m["name"]))
        return {"ok": True, "count": len(modules), "modules": modules}

    def _walk_registry(
        self, node: Any, kind: str, out: list[dict[str, str]], domain: str = ""
    ) -> None:
        if not isinstance(node, dict):
            return
        # skip meta keys
        for key, value in node.items():
            if key.startswith("_"):
                continue
            if isinstance(value, dict) and "path" in value:
                out.append(
                    {
                        "name": key,
                        "domain": domain or kind,
                        "kind": kind,
                        "path": value.get("path", ""),
                        "description": value.get("description", key),
                    }
                )
            elif isinstance(value, dict):
                self._walk_registry(value, kind, out, domain=key if not domain else domain)

    def search_knowledge(self, query: str, limit: int = 8) -> dict[str, Any]:
        q = query.lower().strip()
        if not q:
            return {"ok": False, "error": "query required"}
        hits: list[dict[str, Any]] = []
        tokens = [t for t in re.split(r"\W+", q) if t]

        def _score_file(kid: str, path: Path, *, rel: str) -> None:
            try:
                text = path.read_text(encoding="utf-8")
            except OSError:
                return
            lower = text.lower()
            score = sum(lower.count(t) for t in tokens)
            if score <= 0:
                return
            idx = lower.find(tokens[0]) if tokens else -1
            start = max(0, idx - 80) if idx >= 0 else 0
            snippet = text[start : start + 240].replace("\n", " ")
            hits.append(
                {
                    "id": kid,
                    "file": rel,
                    "score": score + (50 if rel.startswith("overlay:") else 0),
                    "snippet": snippet,
                }
            )

        for kid, path in self._iter_knowledge_files():
            try:
                rel = str(path.relative_to(self.settings.knowledge_root))
            except ValueError:
                rel = str(path)
            _score_file(kid, path, rel=rel)

        # User knowledge overlay (phase 13)
        try:
            from .paths import knowledge_overlay_dir

            overlay = knowledge_overlay_dir()
            if overlay.is_dir():
                for path in overlay.rglob("*"):
                    if not path.is_file():
                        continue
                    if path.suffix.lower() not in {".md", ".txt", ".json", ".nix"}:
                        continue
                    _score_file(f"overlay/{path.name}", path, rel=f"overlay:{path.name}")
        except Exception:  # noqa: BLE001
            pass

        hits.sort(key=lambda h: h["score"], reverse=True)
        return {"ok": True, "hits": hits[: max(1, min(limit, 20))]}
    def explain_path(self, module_path: str) -> dict[str, Any]:
        path = self._normalize_path(module_path)
        listed = self.list_modules(query=path.split("/")[-1])
        matches = [
            m
            for m in listed.get("modules", [])
            if path in m.get("path", "")
            or m["name"] == path.split("/")[-1]
            or path.endswith(m["name"])
        ]
        knowledge = self.search_knowledge(path.replace("/", " "), limit=5)
        current = self.read_module_config(path)
        return {
            "ok": True,
            "module_path": path,
            "registry_matches": matches,
            "knowledge_hits": knowledge.get("hits", []),
            "current_config": current.get("content") if current.get("ok") else None,
            "notes": (
                "Writes use ncc_write_module_config; enable optional modules "
                "with enable = true in their systemConfig leaf."
            ),
        }

    # --- patch / validate / rebuild -------------------------------------

    def propose_config_patch(self, module_path: str, proposed_nix: str) -> dict[str, Any]:
        path = self._normalize_path(module_path)
        current = self.read_module_config(path)
        before = current.get("content", "") if current.get("ok") else ""
        after = proposed_nix if proposed_nix.endswith("\n") else proposed_nix + "\n"
        before_lines = (before or "").splitlines(keepends=True)
        after_lines = after.splitlines(keepends=True)
        diff = "".join(
            difflib.unified_diff(
                before_lines,
                after_lines,
                fromfile=f"{path}:current",
                tofile=f"{path}:proposed",
            )
        )
        return {
            "ok": True,
            "module_path": path,
            "diff": diff or "(no changes)",
            "current": before,
            "proposed": after,
        }

    def validate_config(
        self, module_path: str | None = None, content_nix: str | None = None
    ) -> dict[str, Any]:
        if content_nix is None and module_path:
            read = self.read_module_config(module_path)
            if not read.get("ok"):
                return read
            content_nix = read.get("content", "{}")
        if content_nix is None:
            return {"ok": False, "error": "Provide module_path and/or content_nix"}

        proc = self._config_cmd("validate", input_text=content_nix)
        if proc.returncode != 0:
            return {
                "ok": False,
                "error": proc.stderr.strip() or proc.stdout.strip() or "validation failed",
            }
        return {
            "ok": True,
            "message": proc.stdout.strip() or "Nix fragment is valid",
            "module_path": module_path,
        }

    def apply_system(
        self, confirm: str, hostname: str | None = None
    ) -> dict[str, Any]:
        if not self.settings.allow_rebuild:
            return {
                "ok": False,
                "error": (
                    "Rebuild disabled. Set allowRebuild = true in "
                    "systemConfig.modules.specialized.ncc-assistant."
                ),
            }
        if confirm != "CONFIRM":
            return {
                "ok": False,
                "error": 'confirm must be exactly "CONFIRM" to run a system rebuild.',
            }

        try:
            from .host_profiles import assert_hostname_allowed

            host_err = assert_hostname_allowed(hostname)
            if host_err:
                return {"ok": False, "error": host_err}
        except ImportError:
            pass

        require_preflight = os.environ.get("AGENT_REQUIRE_PREFLIGHT", "0").lower() in (
            "1",
            "true",
            "yes",
        )
        if require_preflight:
            pre = self.run_preflight()
            if not pre.get("ok"):
                return {
                    "ok": False,
                    "error": "Preflight required before rebuild failed",
                    "preflight": pre,
                }

        host = hostname or self._detect_hostname()
        flake = f"{self.settings.nixos_dir}#{host}"
        cmd = ["sudo", "ncc", "system", "build", "switch", "--flake", flake]
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
        return {
            "ok": proc.returncode == 0,
            "command": " ".join(cmd),
            "stdout": proc.stdout[-4000:],
            "stderr": proc.stderr[-4000:],
            "returncode": proc.returncode,
        }
    def _detect_hostname(self) -> str:
        try:
            return Path("/etc/hostname").read_text(encoding="utf-8").strip() or "nixos"
        except OSError:
            return "nixos"

    def _normalize_path(self, module_path: str) -> str:
        p = module_path.strip().lstrip("/")
        p = re.sub(r"\.nix$", "", p)
        p = re.sub(r"/config$", "", p)
        # Accept systemConfig.modules... style
        if p.startswith("systemConfig."):
            p = p[len("systemConfig.") :]
            p = p.replace(".", "/")
        return p

    def _check_kill_switch(self) -> str | None:
        """Check if kill-switch is active. Returns error message or None."""
        from .paths import is_disabled
        if is_disabled():
            return "Operations disabled by kill-switch (DISABLE file exists)"
        return None

    def _check_presence_for_mutating(self, name: str) -> str | None:
        """Check presence state for mutating tools."""
        if name not in MUTATING_TOOLS:
            return None
        from .presence import is_paused, get_presence
        if is_paused():
            presence = get_presence()
            return f"Agent paused: {presence.reason or 'no reason given'}"
        return None

    def _check_rate_limit(self, name: str, max_calls: int | None) -> str | None:
        """Check rate limit for a tool. Returns error message or None."""
        if max_calls is None:
            # Default soft caps for builtins that can spam
            defaults = {
                "apply_module_config": 10,
                "apply_system": 2,
                "run_preflight": 5,
            }
            max_calls = defaults.get(name)
        if max_calls is None:
            return None
        count = self._call_counts.get(name, 0)
        if count >= max_calls:
            return f"Rate limit exceeded for {name}: {count}/{max_calls} calls"
        return None

    def _check_min_interval(self, name: str, min_interval_ms: int | None) -> str | None:
        if not min_interval_ms:
            return None
        last = getattr(self, "_last_call_ms", {}).get(name)
        now = int(time.time() * 1000)
        if last is not None and now - last < min_interval_ms:
            return (
                f"Rate limit: {name} min interval {min_interval_ms}ms "
                f"(retry in {min_interval_ms - (now - last)}ms)"
            )
        if not hasattr(self, "_last_call_ms"):
            self._last_call_ms = {}
        self._last_call_ms[name] = now
        return None

    def _shell_allowlisted(self, command: str) -> bool:
        raw = os.environ.get("NCC_ASSISTANT_SHELL_ALLOWLIST", "").strip()
        if not raw:
            return True  # empty allowlist = allow when shell enabled
        prefixes = [p.strip() for p in raw.split(":") if p.strip()]
        cmd = command.strip()
        return any(cmd == p or cmd.startswith(p + " ") for p in prefixes)

    def _request_confirmation(self, payload: dict[str, Any]) -> bool:
        """GUI confirm_hook or notification DecisionService for headless/agent."""
        if self.confirm_hook is not None:
            return bool(self.confirm_hook(payload))

        confirm_mode = os.environ.get("AGENT_CONFIRM", "writes").lower()
        level = payload.get("level", "write")
        if confirm_mode == "never":
            return True
        if confirm_mode == "writes" and level not in ("write", "rebuild"):
            return True

        from .notifications import get_decision_service

        svc = get_decision_service()
        timeout = int(os.environ.get("NOTIFY_TIMEOUT_SEC") or os.environ.get("NCC_ASSISTANT_NOTIFY_TIMEOUT_SEC") or "300")
        decision = svc.create(
            kind=f"{level}_confirm",
            title=str(payload.get("title") or "Confirm tool"),
            summary=str(payload.get("summary") or ""),
            detail=str(payload.get("detail") or "")[:4000],
            tool=str(payload.get("tool") or ""),
            timeout_sec=timeout,
        )
        result = svc.wait_for_decision(decision.id, timeout_sec=timeout)
        return result == "allow"
    def _record_call(self, name: str) -> None:
        """Record a tool call for rate limiting."""
        self._call_counts[name] = self._call_counts.get(name, 0) + 1

    def _call_mcp_tool(self, name: str, args: dict[str, Any]) -> dict[str, Any]:
        """Call an MCP tool (name format: mcp.<server>.<tool>)."""
        parts = name.split(".", 2)
        if len(parts) != 3:
            return {"ok": False, "error": f"Invalid MCP tool name: {name}"}
        _, server, tool = parts
        try:
            pool = self._get_mcp_pool()
            return pool.call_tool(server, tool, args)
        except Exception as exc:
            return {"ok": False, "error": f"MCP call failed: {exc}"}

    def _call_shell_tool(self, name: str, args: dict[str, Any], command: str) -> dict[str, Any]:
        """Call a shell tool with argument substitution."""
        if not self.settings.allow_shell:
            return {"ok": False, "error": "Shell tools are disabled"}

        cmd = command
        for key, value in args.items():
            placeholder = "{{" + key + "}}"
            cmd = cmd.replace(placeholder, str(value))

        if not self._shell_allowlisted(cmd):
            return {
                "ok": False,
                "error": (
                    f"Shell command not in allowlist: {cmd[:120]}. "
                    "Configure tools.shellAllowlist in systemConfig."
                ),
            }

        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=300,
                check=False,
            )
            return {
                "ok": result.returncode == 0,
                "stdout": result.stdout[-4000:],
                "stderr": result.stderr[-2000:],
                "returncode": result.returncode,
            }
        except subprocess.TimeoutExpired:
            return {"ok": False, "error": "Shell command timed out"}
        except Exception as exc:
            return {"ok": False, "error": f"Shell error: {exc}"}

    def run_preflight(self) -> dict[str, Any]:
        """Run preflight checks before rebuild."""
        prebuild_script = "/etc/nixos/prebuild.sh"
        if not os.path.isfile(prebuild_script):
            return {"ok": True, "message": "No prebuild script found, skipping"}

        try:
            result = subprocess.run(
                [prebuild_script],
                capture_output=True,
                text=True,
                timeout=120,
                check=False,
            )
            return {
                "ok": result.returncode == 0,
                "stdout": result.stdout[-2000:],
                "stderr": result.stderr[-1000:],
                "returncode": result.returncode,
            }
        except subprocess.TimeoutExpired:
            return {"ok": False, "error": "Preflight script timed out"}
        except Exception as exc:
            return {"ok": False, "error": f"Preflight error: {exc}"}

    def config_health_report(self) -> dict[str, Any]:
        """Generate configuration health report."""
        from .health import config_health_report
        report = config_health_report(self.settings)
        return {"ok": True, **report.to_dict()}

    def memory_list(self, tag: str | None = None, limit: int = 20) -> dict[str, Any]:
        """List memory notes."""
        from .memory import list_notes
        notes = list_notes(tag=tag, limit=limit)
        return {
            "ok": True,
            "count": len(notes),
            "notes": [n.to_dict() for n in notes],
        }

    def memory_add(self, content: str, tags: list[str] | None = None) -> dict[str, Any]:
        """Add a memory note."""
        from .memory import add_note
        note = add_note(content, tags=tags, source="agent")
        return {"ok": True, "note_id": note.id}

    def memory_forget(self, note_id: str) -> dict[str, Any]:
        """Forget a memory note."""
        from .memory import forget_note
        success = forget_note(note_id)
        if success:
            return {"ok": True, "message": f"Forgot note {note_id}"}
        return {"ok": False, "error": f"Note {note_id} not found"}

    def list_config_backups(self, limit: int = 20) -> dict[str, Any]:
        """List NixOS configuration backups."""
        backup_dir = Path("/var/backup/nixos")
        if not backup_dir.is_dir():
            return {"ok": True, "count": 0, "backups": [], "message": "Backup directory not found"}

        backups: list[dict[str, Any]] = []
        try:
            entries = list(backup_dir.iterdir())
        except PermissionError:
            return {
                "ok": True,
                "count": 0,
                "backups": [],
                "message": f"Permission denied reading {backup_dir}",
            }
        for path in sorted(entries, key=lambda p: p.stat().st_mtime, reverse=True):
            if len(backups) >= limit:
                break
            try:
                stat = path.stat()
            except OSError:
                continue
            backups.append({
                "name": path.name,
                "path": str(path),
                "size": stat.st_size,
                "mtime": stat.st_mtime,
            })

        return {"ok": True, "count": len(backups), "backups": backups}

    def list_boot_generations(self, limit: int = 20) -> dict[str, Any]:
        """List nixos boot generations for rollback guidance."""
        try:
            proc = subprocess.run(
                ["nixos-rebuild", "list-generations"],
                capture_output=True,
                text=True,
                check=False,
                timeout=30,
            )
            if proc.returncode != 0:
                # Fallback: profile links
                profile = Path("/nix/var/nix/profiles/system")
                gens = []
                if profile.parent.is_dir():
                    for p in sorted(profile.parent.glob("system-*-link"), reverse=True):
                        gens.append({"name": p.name, "path": str(p)})
                        if len(gens) >= limit:
                            break
                return {
                    "ok": True,
                    "count": len(gens),
                    "generations": gens,
                    "stderr": proc.stderr[-1000:],
                    "source": "profile-links",
                }
            lines = [ln for ln in proc.stdout.splitlines() if ln.strip()]
            return {
                "ok": True,
                "count": len(lines[:limit]),
                "generations": [{"line": ln} for ln in lines[:limit]],
                "source": "nixos-rebuild",
            }
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "error": str(exc)}

    def restore_config_backup(self, backup_path: str, *, confirm: bool = False) -> dict[str, Any]:
        """Restore a backup file path into the active monolith (guarded)."""
        if not confirm:
            return {
                "ok": False,
                "error": "confirm=true required to restore a backup",
                "backup_path": backup_path,
            }
        if not self.settings.writes_enabled:
            return {"ok": False, "error": "Writes disabled"}
        src = Path(backup_path)
        if not src.is_file():
            return {"ok": False, "error": f"Backup not found: {backup_path}"}
        # Only allow under known backup roots
        allowed_roots = [Path("/var/backup/nixos"), Path.home() / ".config" / "ncc-assistant" / "backups"]
        if not any(str(src.resolve()).startswith(str(r.resolve())) for r in allowed_roots if r.exists() or True):
            # still require path under /var/backup/nixos or user backups
            resolved = str(src.resolve())
            if "/var/backup/nixos" not in resolved and "/.config/ncc-assistant/backups" not in resolved:
                return {"ok": False, "error": "Backup path not under an allowed backup root"}
        content = src.read_text(encoding="utf-8")
        # Heuristic: if looks like a module leaf, refuse full monolith restore via this tool
        return {
            "ok": True,
            "message": (
                "Backup content loaded for guided restore. "
                "Use apply_module_config with the relevant leaf, or restore manually."
            ),
            "backup_path": str(src),
            "size": len(content),
            "preview": content[:2000],
        }
    def agent_finish(self, summary: str, success: bool) -> dict[str, Any]:
        """Agent finish handler (actual finish is handled by AgentRunner)."""
        return {"ok": True, "message": "Agent finished", "summary": summary, "success": success}

    def call(self, name: str, arguments: dict[str, Any] | None = None) -> dict[str, Any]:
        args = dict(arguments or {})
        try:
            kill_err = self._check_kill_switch()
            if kill_err and name in MUTATING_TOOLS:
                from .audit import append_audit
                try:
                    append_audit("deny", tool=name, result="denied", detail=kill_err)
                except Exception:  # noqa: BLE001
                    pass
                return {"ok": False, "error": kill_err}

            presence_err = self._check_presence_for_mutating(name)
            if presence_err:
                return {"ok": False, "error": presence_err}

            if self._dry_run and name in MUTATING_TOOLS:
                return {
                    "ok": False,
                    "error": "Dry-run mode: write operations are simulated",
                    "dry_run": True,
                    "would_call": name,
                    "args": args,
                }

            from .registry import get_registry
            registry = get_registry()
            tool_entry = registry.get(name)

            if tool_entry and not tool_entry.enabled:
                return {"ok": False, "error": f"Tool disabled: {name}"}

            max_calls = tool_entry.max_calls_per_job if tool_entry else None
            rate_err = self._check_rate_limit(name, max_calls)
            if rate_err:
                return {"ok": False, "error": rate_err}
            min_ms = None
            if tool_entry and getattr(tool_entry, "min_interval_ms", None):
                min_ms = tool_entry.min_interval_ms  # type: ignore[attr-defined]
            interval_err = self._check_min_interval(name, min_ms)
            if interval_err:
                return {"ok": False, "error": interval_err}

            if name.startswith("mcp."):
                self._record_call(name)
                return self._call_mcp_tool(name, args)

            if tool_entry and tool_entry.kind == "shell":
                if not tool_entry.command:
                    return {"ok": False, "error": f"Shell tool {name} has no command"}
                self._record_call(name)
                return self._call_shell_tool(name, args, tool_entry.command)

            if name == "apply_module_config":
                wants_write = args.get("confirm") in (True, "true", "1", 1)
                # Interactive GUI: always prompt before write; headless only if confirm=true
                if self.confirm_hook is not None or wants_write:
                    preview = ""
                    try:
                        proposal = self.propose_config_patch(
                            args.get("module_path", ""), args.get("content_nix", "")
                        )
                        preview = proposal.get("diff") or proposal.get("error") or ""
                    except Exception:  # noqa: BLE001
                        preview = (args.get("content_nix") or "")[:2000]
                    ok = self._request_confirmation(
                        {
                            "tool": name,
                            "level": "write",
                            "title": "Write module config?",
                            "summary": f"Write config to {args.get('module_path', '?')}",
                            "detail": str(preview)[:4000],
                        }
                    )
                    if not ok:
                        return {"ok": False, "error": "Cancelled by user / notification timeout."}
                    args["confirm"] = True

            if name == "apply_system":
                wants_rebuild = args.get("confirm") == "CONFIRM"
                if self.confirm_hook is not None or wants_rebuild:
                    ok = self._request_confirmation(
                        {
                            "tool": name,
                            "level": "rebuild",
                            "title": "Rebuild system?",
                            "summary": (
                                "Run ncc system build switch "
                                f"(host={args.get('hostname') or 'default'})"
                            ),
                            "detail": (
                                "This can change the running system. "
                                'Requires allowRebuild and confirm "CONFIRM".'
                            ),
                        }
                    )
                    if not ok:
                        return {"ok": False, "error": "Cancelled by user / notification timeout."}
                    args["confirm"] = "CONFIRM"

            if name == "restore_config_backup":
                wants = args.get("confirm") in (True, "true", "1", 1)
                if self.confirm_hook is not None or wants:
                    ok = self._request_confirmation(
                        {
                            "tool": name,
                            "level": "write",
                            "title": "Restore config backup?",
                            "summary": f"Load backup {args.get('backup_path', '?')}",
                            "detail": "Guided restore — review preview before applying leaves.",
                        }
                    )
                    if not ok:
                        return {"ok": False, "error": "Cancelled by user / notification timeout."}
                    args["confirm"] = True

            confirm_mode = os.environ.get("AGENT_CONFIRM", "writes").lower()
            # Confirm-always is for agent/headless; GUI chat already uses confirm_hook for writes.
            if (
                confirm_mode == "always"
                and self.confirm_hook is None
                and name not in MUTATING_TOOLS
                and name != "agent_finish"
            ):
                ok = self._request_confirmation(
                    {
                        "tool": name,
                        "level": "tool",
                        "title": f"Allow tool {name}?",
                        "summary": f"Confirm mode=always: {name}",
                        "detail": json.dumps(args)[:2000],
                    }
                )
                if not ok:
                    return {"ok": False, "error": "Cancelled by confirm=always policy."}

            self._record_call(name)

            if name == "list_modules":
                return self.list_modules(args.get("query"))
            if name == "read_module_config":
                return self.read_module_config(args["module_path"])
            if name == "search_knowledge":
                return self.search_knowledge(
                    args["query"], int(args.get("limit", 8))
                )
            if name == "explain_path":
                return self.explain_path(args["module_path"])
            if name == "propose_config_patch":
                return self.propose_config_patch(
                    args["module_path"], args["proposed_nix"]
                )
            if name == "apply_module_config":
                return self.apply_module_config(
                    args["module_path"],
                    args["content_nix"],
                    bool(args.get("confirm", False)),
                )
            if name == "validate_config":
                return self.validate_config(
                    args.get("module_path"), args.get("content_nix")
                )
            if name == "apply_system":
                return self.apply_system(args.get("confirm", ""), args.get("hostname"))
            if name == "run_preflight":
                return self.run_preflight()
            if name == "config_health_report":
                return self.config_health_report()
            if name == "memory_list":
                return self.memory_list(args.get("tag"), int(args.get("limit", 20)))
            if name == "memory_add":
                return self.memory_add(args["content"], args.get("tags"))
            if name == "memory_forget":
                return self.memory_forget(args["note_id"])
            if name == "list_config_backups":
                return self.list_config_backups(int(args.get("limit", 20)))
            if name == "list_boot_generations":
                return self.list_boot_generations(int(args.get("limit", 20)))
            if name == "disk_nix_report":
                from .probes import run_disk_nix_probe

                thr = float(args.get("threshold_pct", 85))
                measure = bool(args.get("measure_store", False))
                return {
                    "ok": True,
                    **run_disk_nix_probe(
                        threshold_pct=thr, measure_store=measure
                    ).to_dict(),
                }
            if name == "restore_config_backup":
                return self.restore_config_backup(
                    args["backup_path"], confirm=bool(args.get("confirm", False))
                )
            if name == "agent_finish":
                return self.agent_finish(args.get("summary", ""), args.get("success", True))
            return {"ok": False, "error": f"Unknown tool: {name}"}
        except KeyError as exc:
            return {"ok": False, "error": f"Missing argument: {exc}"}
        except Exception as exc:  # noqa: BLE001 — surface to LLM clients
            return {"ok": False, "error": f"{type(exc).__name__}: {exc}"}

    def openai_tools(self) -> list[dict[str, Any]]:
        """Return OpenAI function-calling format using registry."""
        try:
            from .registry import get_registry
            registry = get_registry()
            return registry.openai_tools()
        except ImportError:
            pass

        tools = []
        for t in TOOL_DEFINITIONS:
            tools.append(
                {
                    "type": "function",
                    "function": {
                        "name": t["name"],
                        "description": t["description"],
                        "parameters": t.get("inputSchema", {"type": "object"}),
                    },
                }
            )
        return tools
