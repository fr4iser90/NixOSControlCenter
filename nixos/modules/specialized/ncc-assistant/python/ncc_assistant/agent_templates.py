"""Agent workflow templates (catalog + instances + run/schedule bind)."""

from __future__ import annotations

import json
import os
import re
import uuid
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .paths import agent_instances_dir, agent_templates_dir

_SAFE_RE = re.compile(r"[^a-zA-Z0-9_-]+")


@dataclass
class TemplateParam:
    id: str
    label: str
    type: str = "string"
    required: bool = False
    default: Any = None
    options: list[str] = field(default_factory=list)
    secret_kind: str | None = None
    description: str = ""

    @classmethod
    def from_dict(cls, raw: dict[str, Any]) -> TemplateParam:
        return cls(
            id=str(raw.get("id") or ""),
            label=str(raw.get("label") or raw.get("id") or ""),
            type=str(raw.get("type") or "string"),
            required=bool(raw.get("required", False)),
            default=raw.get("default"),
            options=[str(x) for x in (raw.get("options") or [])],
            secret_kind=raw.get("secretKind") or raw.get("secret_kind"),
            description=str(raw.get("description") or ""),
        )


@dataclass
class AgentTemplate:
    id: str
    title: str
    category: str = "Custom"
    description: str = ""
    skill: str | None = None
    profile: str = "read-only"
    mcp: list[str] = field(default_factory=list)
    requires_secrets: list[str] = field(default_factory=list)
    params: list[TemplateParam] = field(default_factory=list)
    schedule_kind: str | None = None
    tags: list[str] = field(default_factory=list)
    tier: str = "catalog"  # catalog | beta (UI section only — not a quality claim)
    goal_template: str = ""
    dry_run: bool = True
    max_steps: int | None = 24
    source: str = "builtin"
    path: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {
            "id": self.id,
            "title": self.title,
            "category": self.category,
            "description": self.description,
            "skill": self.skill,
            "profile": self.profile,
            "mcp": list(self.mcp),
            "requiresSecrets": list(self.requires_secrets),
            "params": [
                {
                    "id": p.id,
                    "label": p.label,
                    "type": p.type,
                    "required": p.required,
                    "default": p.default,
                    "options": p.options,
                    "secretKind": p.secret_kind,
                    "description": p.description,
                }
                for p in self.params
            ],
            "scheduleKind": self.schedule_kind,
            "tags": list(self.tags),
            "tier": self.tier,
            "goalTemplate": self.goal_template,
            "dryRun": self.dry_run,
            "maxSteps": self.max_steps,
            "source": self.source,
        }

    @classmethod
    def from_dict(
        cls, data: dict[str, Any], *, source: str = "builtin", path: str | None = None
    ) -> AgentTemplate | None:
        tid = str(data.get("id") or "").strip()
        title = str(data.get("title") or "").strip()
        if not tid or not title:
            return None
        params_raw = data.get("params") or []
        params = [
            TemplateParam.from_dict(p)
            for p in params_raw
            if isinstance(p, dict) and p.get("id")
        ]
        return cls(
            id=tid,
            title=title,
            category=str(data.get("category") or "Custom"),
            description=str(data.get("description") or ""),
            skill=data.get("skill"),
            profile=str(data.get("profile") or "read-only"),
            mcp=[str(x) for x in (data.get("mcp") or [])],
            requires_secrets=[
                str(x) for x in (data.get("requiresSecrets") or data.get("requires_secrets") or [])
            ],
            params=params,
            schedule_kind=data.get("scheduleKind") or data.get("schedule_kind"),
            tags=[str(x) for x in (data.get("tags") or [])],
            tier=(
                "catalog"
                if str(data.get("tier") or data.get("section") or "catalog")
                in ("catalog", "proven", "")
                else str(data.get("tier") or "beta")
            ),
            goal_template=str(
                data.get("goalTemplate") or data.get("goal_template") or data.get("goal") or ""
            ),
            dry_run=bool(data.get("dryRun", data.get("dry_run", True))),
            max_steps=data.get("maxSteps", data.get("max_steps", 24)),
            source=source,
            path=path,
        )


@dataclass
class AgentInstance:
    id: str
    template_id: str
    title: str
    params: dict[str, Any] = field(default_factory=dict)
    enabled_schedule: bool = False
    provider_id: str | None = None
    model: str | None = None
    created: str = ""
    updated: str = ""
    path: str | None = None

    def to_dict(self) -> dict[str, Any]:
        d: dict[str, Any] = {
            "id": self.id,
            "templateId": self.template_id,
            "title": self.title,
            "params": dict(self.params),
            "enabledSchedule": self.enabled_schedule,
            "created": self.created,
            "updated": self.updated,
        }
        if self.provider_id:
            d["providerId"] = self.provider_id
        if self.model:
            d["model"] = self.model
        return d

    @classmethod
    def from_dict(cls, data: dict[str, Any], path: str | None = None) -> AgentInstance | None:
        iid = str(data.get("id") or "").strip()
        tid = str(data.get("templateId") or data.get("template_id") or "").strip()
        if not iid or not tid:
            return None
        params = dict(data.get("params") or {})
        # Legacy: provider/model nested in params
        provider_id = data.get("providerId") or data.get("provider_id") or params.pop("_providerId", None)
        model = data.get("model") or params.pop("_model", None)
        return cls(
            id=iid,
            template_id=tid,
            title=str(data.get("title") or iid),
            params=params,
            enabled_schedule=bool(data.get("enabledSchedule", data.get("enabled_schedule", False))),
            provider_id=str(provider_id).strip() if provider_id else None,
            model=str(model).strip() if model else None,
            created=str(data.get("created") or ""),
            updated=str(data.get("updated") or ""),
            path=path,
        )


def _now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _template_dirs() -> list[Path]:
    dirs: list[Path] = []
    local = Path(__file__).resolve().parent / "templates" / "agents"
    dirs.append(local)
    root = os.environ.get("NCC_ASSISTANT_ROOT", "").strip()
    if root:
        dirs.append(Path(root) / "ncc_assistant" / "templates" / "agents")
        dirs.append(Path(root) / "templates" / "agents")
    dirs.append(agent_templates_dir())
    seen: set[str] = set()
    out: list[Path] = []
    for d in dirs:
        key = str(d)
        if key not in seen:
            seen.add(key)
            out.append(d)
    return out


def _load_templates_from(directory: Path, source: str) -> list[AgentTemplate]:
    items: list[AgentTemplate] = []
    if not directory.is_dir():
        return items
    for path in sorted(directory.glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if not isinstance(data, dict):
                continue
            if not data.get("id"):
                data["id"] = path.stem
            tmpl = AgentTemplate.from_dict(data, source=source, path=str(path))
            if tmpl:
                items.append(tmpl)
        except (OSError, json.JSONDecodeError):
            continue
    return items


def list_agent_templates() -> list[AgentTemplate]:
    by_id: dict[str, AgentTemplate] = {}
    for directory in _template_dirs():
        source = "user" if directory == agent_templates_dir() else "builtin"
        for tmpl in _load_templates_from(directory, source):
            by_id[tmpl.id] = tmpl
    def _tier_rank(t: AgentTemplate) -> int:
        tier = "catalog" if t.tier in ("proven", "catalog", "") else t.tier
        return 0 if tier == "catalog" else 1

    return sorted(by_id.values(), key=lambda t: (_tier_rank(t), t.category, t.title))


def get_agent_template(template_id: str) -> AgentTemplate | None:
    for tmpl in list_agent_templates():
        if tmpl.id == template_id:
            return tmpl
    return None


def load_skill_text(skill_ref: str | None) -> str:
    if not skill_ref:
        return ""
    ref = skill_ref.strip()
    candidates: list[Path] = []
    # Packaged prompts live next to the module (copied to NCC_PROMPTS_ROOT).
    prompts = os.environ.get("NCC_PROMPTS_ROOT", "").strip()
    if prompts:
        candidates.append(Path(prompts) / ref)
        candidates.append(Path(prompts) / "skills" / Path(ref).name)
    # Dev checkout: module prompts/ beside python/
    module_prompts = Path(__file__).resolve().parents[2] / "prompts"
    candidates.append(module_prompts / ref)
    candidates.append(module_prompts / "skills" / Path(ref).name)
    root = os.environ.get("NCC_ASSISTANT_ROOT", "").strip()
    if root:
        candidates.append(Path(root) / "prompts" / ref)
        candidates.append(Path(root) / ref)
    for path in candidates:
        if path.is_file():
            try:
                return path.read_text(encoding="utf-8")
            except OSError:
                continue
    return ""


def template_badges(tmpl: AgentTemplate) -> list[dict[str, str]]:
    """Return badge dicts: {label, kind} kind in ok|warn|missing."""
    from .marketplace import installed_mcp_names
    from .secrets import has_secret

    badges: list[dict[str, str]] = []
    installed = installed_mcp_names()
    missing_mcp = [m for m in tmpl.mcp if m not in installed]
    if missing_mcp:
        badges.append(
            {
                "label": f"{len(missing_mcp)} MCP to connect before launch",
                "kind": "warn",
            }
        )
    else:
        for m in tmpl.mcp:
            if m in ("github", "git"):
                badges.append({"label": f"{m.title()} Connected", "kind": "ok"})
                break
        else:
            if tmpl.mcp:
                badges.append({"label": "MCPs ready", "kind": "ok"})

    missing_secrets = [s for s in tmpl.requires_secrets if not has_secret(s)]
    # Also check secretRef params with defaults / kinds
    for p in tmpl.params:
        if p.type == "secretRef" and p.secret_kind and not has_secret(p.secret_kind):
            # only count if required
            if p.required and p.secret_kind not in missing_secrets:
                missing_secrets.append(p.secret_kind)

    for name in missing_secrets:
        badges.append({"label": f"Secret missing: {name}", "kind": "missing"})
    if tmpl.requires_secrets and not missing_secrets:
        if any(s in ("github_token",) for s in tmpl.requires_secrets):
            badges.append({"label": "GitHub Connected", "kind": "ok"})
    return badges


def validate_instance_params(
    tmpl: AgentTemplate, params: dict[str, Any]
) -> list[str]:
    """Return list of validation errors (empty = ok)."""
    from .secrets import has_secret
    from .workspaces import get_workspace

    errors: list[str] = []
    for p in tmpl.params:
        raw = params.get(p.id, p.default)
        if p.required and (raw is None or raw == "" or raw == []):
            errors.append(f"Required: {p.label}")
            continue
        if raw is None or raw == "":
            continue
        if p.type == "secretRef":
            name = str(raw).strip()
            if not has_secret(name):
                errors.append(f"Unknown or empty secret: {name}")
        elif p.type == "workspaceList":
            ids = raw if isinstance(raw, list) else [x.strip() for x in str(raw).split(",") if x.strip()]
            if p.required and not ids:
                errors.append(f"Required: {p.label}")
            for wid in ids:
                if get_workspace(str(wid)) is None:
                    errors.append(f"Unknown workspace: {wid}")
        elif p.type == "enum" and p.options and str(raw) not in p.options:
            errors.append(f"{p.label}: must be one of {', '.join(p.options)}")
    return errors


def render_goal(tmpl: AgentTemplate, params: dict[str, Any]) -> str:
    skill = load_skill_text(tmpl.skill)
    goal = tmpl.goal_template or f"Execute the '{tmpl.title}' workflow carefully."
    # Simple {{param}} expansion in goal_template
    for key, value in params.items():
        if isinstance(value, list):
            rendered = ", ".join(str(x) for x in value)
        else:
            rendered = str(value)
        goal = goal.replace("{{" + key + "}}", rendered)
        goal = goal.replace("{{params." + key + "}}", rendered)

    # Enrich with workspace paths
    from .workspaces import get_workspace

    ws_ids = params.get("repositories") or params.get("workspaces") or []
    if isinstance(ws_ids, str):
        ws_ids = [x.strip() for x in ws_ids.split(",") if x.strip()]
    ws_lines: list[str] = []
    for wid in ws_ids if isinstance(ws_ids, list) else []:
        ws = get_workspace(str(wid))
        if ws:
            line = f"- {ws.id}: {ws.path}"
            if ws.github:
                line += f" (github:{ws.github})"
            ws_lines.append(line)

    parts = [goal.strip()]
    if ws_lines:
        parts.append("Workspaces:\n" + "\n".join(ws_lines))
    if skill.strip():
        parts.append("Skill instructions:\n" + skill.strip())
    # Never interpolate secret values into the goal text
    return "\n\n".join(parts)


def list_instances() -> list[AgentInstance]:
    out: list[AgentInstance] = []
    for path in sorted(agent_instances_dir().glob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            if isinstance(data, dict):
                inst = AgentInstance.from_dict(data, path=str(path))
                if inst:
                    out.append(inst)
        except (OSError, json.JSONDecodeError):
            continue
    return out


def get_instance(instance_id: str) -> AgentInstance | None:
    for inst in list_instances():
        if inst.id == instance_id:
            return inst
    return None


def save_instance(inst: AgentInstance) -> Path:
    safe = _SAFE_RE.sub("-", inst.id).strip("-") or "instance"
    path = agent_instances_dir() / f"{safe}.json"
    now = _now()
    if not inst.created:
        inst.created = now
    inst.updated = now
    inst.path = str(path)
    path.write_text(json.dumps(inst.to_dict(), indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return path


def delete_instance(instance_id: str) -> bool:
    inst = get_instance(instance_id)
    if not inst or not inst.path:
        # try direct file
        path = agent_instances_dir() / f"{_SAFE_RE.sub('-', instance_id)}.json"
        if path.is_file():
            path.unlink()
            return True
        return False
    Path(inst.path).unlink(missing_ok=True)
    return True


def settings_for_instance(inst: AgentInstance):
    """Build Settings with instance provider/model + cached credentials."""
    from dataclasses import replace

    from .auth import with_cached_credentials
    from .config import Settings
    from .providers import apply_provider_settings, get_provider

    settings = with_cached_credentials(Settings.from_env(client_mode="chat"))
    if inst.provider_id:
        prov = get_provider(inst.provider_id)
        if prov is not None:
            settings = apply_provider_settings(settings, prov)
            settings = with_cached_credentials(settings)
    if inst.model:
        settings = replace(settings, model=inst.model)
    return settings


def instantiate(
    template_id: str,
    params: dict[str, Any],
    *,
    instance_id: str | None = None,
    title: str | None = None,
    enable_schedule: bool = False,
    save_playbook: bool = True,
    provider_id: str | None = None,
    model: str | None = None,
    update_existing: bool = False,
) -> dict[str, Any]:
    """
    Validate params, persist instance, optionally write a user playbook + schedule.
    """
    tmpl = get_agent_template(template_id)
    if tmpl is None:
        return {"ok": False, "error": f"Unknown template: {template_id}"}

    # Apply defaults
    merged = {p.id: p.default for p in tmpl.params if p.default is not None}
    merged.update(params or {})
    errors = validate_instance_params(tmpl, merged)
    if errors:
        return {"ok": False, "error": "; ".join(errors), "errors": errors}

    if update_existing and instance_id:
        prev = get_instance(instance_id)
        if prev is None:
            return {"ok": False, "error": f"Unknown instance: {instance_id}"}
        iid = prev.id
        created = prev.created
        title_final = title or prev.title
    else:
        prev = None
        iid = (instance_id or f"{template_id}-{uuid.uuid4().hex[:8]}").strip()
        created = ""
        title_final = title or f"{tmpl.title} ({iid})"

    inst = AgentInstance(
        id=iid,
        template_id=template_id,
        title=title_final,
        params=merged,
        enabled_schedule=enable_schedule,
        provider_id=(provider_id or (prev.provider_id if prev else None)) or None,
        model=(model or (prev.model if prev else None)) or None,
        created=created,
    )
    # Explicit empty string from UI means clear
    if provider_id is not None:
        inst.provider_id = provider_id.strip() or None
    if model is not None:
        inst.model = model.strip() or None
    path = save_instance(inst)
    goal = render_goal(tmpl, merged)

    playbook_name = None
    if save_playbook:
        from .playbooks import Playbook, save_user_playbook

        playbook_name = f"tmpl-{iid}"
        save_user_playbook(
            Playbook(
                name=playbook_name,
                description=f"From template {tmpl.id}",
                goal=goal,
                profile=tmpl.profile,
                dry_run=tmpl.dry_run,
                max_steps=tmpl.max_steps,
                tags=["agent-template", tmpl.id, *tmpl.tags],
            )
        )

    schedule_name = None
    if enable_schedule:
        from .schedule_freq import normalize_on_calendar
        from .schedule_templates import ScheduleSpec, save_user_schedule

        freq = normalize_on_calendar(
            str(merged.get("checkFrequency") or merged.get("onCalendar") or "daily")
        )
        # Persist normalized calendar back onto instance params for clarity
        merged["checkFrequency"] = freq
        inst.params = merged
        save_instance(inst)
        schedule_name = f"tmpl-{iid}"
        save_user_schedule(
            ScheduleSpec(
                name=schedule_name,
                onCalendar=freq,
                playbook=playbook_name,
                goal=goal if not playbook_name else None,
                profile=tmpl.profile,
                dryRun=tmpl.dry_run,
                maxSteps=tmpl.max_steps,
                enable=True,
                description=tmpl.title,
                kind="agent",
            )
        )

    # Best-effort MCP install for first workspace
    mcp_results: list[dict[str, Any]] = []
    ws_ids = merged.get("repositories") or merged.get("workspaces") or []
    if isinstance(ws_ids, str):
        ws_ids = [x.strip() for x in ws_ids.split(",") if x.strip()]
    first_ws = str(ws_ids[0]) if isinstance(ws_ids, list) and ws_ids else None
    secret_name = None
    for p in tmpl.params:
        if p.type == "secretRef" and merged.get(p.id):
            secret_name = str(merged[p.id])
            break
    if tmpl.mcp:
        from .marketplace import install_template

        for mcp_name in tmpl.mcp:
            overrides = {}
            if secret_name and mcp_name == "github":
                overrides = {"GITHUB_PERSONAL_ACCESS_TOKEN": secret_name}
            res = install_template(
                mcp_name,
                workspace_id=first_ws,
                secret_overrides=overrides or None,
                install_as=f"{mcp_name}-{first_ws}" if first_ws and mcp_name == "git" else None,
            )
            mcp_results.append(res)

    return {
        "ok": True,
        "instance": inst.to_dict(),
        "path": str(path),
        "goal": goal,
        "playbook": playbook_name,
        "schedule": schedule_name,
        "mcp": mcp_results,
    }


def run_instance(instance_id: str, *, dry_run: bool | None = None):
    """Yield agent events for a saved instance."""
    from .agent import run_agent

    inst = get_instance(instance_id)
    if inst is None:
        raise ValueError(f"Unknown instance: {instance_id}")
    tmpl = get_agent_template(inst.template_id)
    if tmpl is None:
        raise ValueError(f"Template missing for instance: {inst.template_id}")
    goal = render_goal(tmpl, inst.params)
    settings = settings_for_instance(inst)
    return run_agent(
        goal,
        settings,
        max_steps=tmpl.max_steps or settings.agent_max_steps,
        dry_run=tmpl.dry_run if dry_run is None else dry_run,
        profile=tmpl.profile,
        playbook=f"tmpl-{inst.id}",
    )
