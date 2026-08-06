"""Shared tool runtime for MCP and built-in chat."""

from __future__ import annotations

import difflib
import json
import os
import re
import subprocess
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
]


class ToolRuntime:
    def __init__(
        self,
        settings: Settings,
        confirm_hook: Callable[[dict[str, Any]], bool] | None = None,
    ):
        self.settings = settings
        self.confirm_hook = confirm_hook
        self._index: dict[str, Any] | None = None

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
        for kid, path in self._iter_knowledge_files():
            try:
                text = path.read_text(encoding="utf-8")
            except OSError:
                continue
            lower = text.lower()
            score = sum(lower.count(t) for t in tokens)
            if score <= 0:
                continue
            # Grab a small snippet around first token
            idx = lower.find(tokens[0]) if tokens else -1
            start = max(0, idx - 80) if idx >= 0 else 0
            snippet = text[start : start + 240].replace("\n", " ")
            hits.append(
                {
                    "id": kid,
                    "file": str(path.relative_to(self.settings.knowledge_root)),
                    "score": score,
                    "snippet": snippet,
                }
            )
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

    def call(self, name: str, arguments: dict[str, Any] | None = None) -> dict[str, Any]:
        args = dict(arguments or {})
        try:
            if name == "apply_module_config" and self.confirm_hook is not None:
                preview = ""
                try:
                    proposal = self.propose_config_patch(
                        args.get("module_path", ""), args.get("content_nix", "")
                    )
                    preview = proposal.get("diff") or proposal.get("error") or ""
                except Exception:  # noqa: BLE001
                    preview = (args.get("content_nix") or "")[:2000]
                ok = self.confirm_hook(
                    {
                        "tool": name,
                        "level": "write",
                        "title": "Write module config?",
                        "summary": (
                            f"Write config to {args.get('module_path', '?')}"
                        ),
                        "detail": str(preview)[:4000],
                    }
                )
                if not ok:
                    return {"ok": False, "error": "Cancelled by user in GUI."}
                args["confirm"] = True

            if name == "apply_system" and self.confirm_hook is not None:
                ok = self.confirm_hook(
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
                    return {"ok": False, "error": "Cancelled by user in GUI."}
                args["confirm"] = "CONFIRM"

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
            return {"ok": False, "error": f"Unknown tool: {name}"}
        except KeyError as exc:
            return {"ok": False, "error": f"Missing argument: {exc}"}
        except Exception as exc:  # noqa: BLE001 — surface to LLM clients
            return {"ok": False, "error": f"{type(exc).__name__}: {exc}"}

    def openai_tools(self) -> list[dict[str, Any]]:
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
