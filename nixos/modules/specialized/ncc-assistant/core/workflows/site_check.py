"""Static website-check wave (myline-style, local, no third-party API).

Callers (to be wired): ``cli.cli._cmd_site_check``, companion
``GithubAgentPanel`` / ``window._github_agent_site_check``.
No existing website TLS/header/SEO scanner under ncc-assistant (paths.site_check_*
only). Writes ``~/.config/ncc-assistant/site-checks/latest.json``:
``{updatedAt: ISO-Z, checked, findingCount, results:[{workspaceId, check:{host,
status, securityHeaders, seo, findings, …}}]}``.
User: "workflow wave … domains adden … checks … fr4iser.com oder scan.fr4iser.com".
"""

from __future__ import annotations

import ipaddress
import json
import re
import socket
import ssl
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any
from urllib.parse import urlparse

from core.store.paths import site_check_latest_file
from core.store.workspaces import (
    get_workspace,
    normalize_domain,
    workspaces_with_domains,
)

USER_AGENT = "ncc-assistant-site-check/1.0 (+local; static HTML only)"
TIMEOUT_S = 12
SECURITY_HEADERS = (
    "strict-transport-security",
    "content-security-policy",
    "x-content-type-options",
    "x-frame-options",
    "referrer-policy",
    "permissions-policy",
)
_ATTR_URL = re.compile(
    r"""(?is)(?:src|href)\s*=\s*["'](https?://[^"']+)["']"""
)
_TITLE = re.compile(r"(?is)<title[^>]*>(.*?)</title>")
_META_DESC = re.compile(
    r"""(?is)<meta\s+[^>]*name=["']description["'][^>]*content=["']([^"']*)["']"""
)
_META_DESC_ALT = re.compile(
    r"""(?is)<meta\s+[^>]*content=["']([^"']*)["'][^>]*name=["']description["']"""
)
_CANONICAL = re.compile(
    r"""(?is)<link\s+[^>]*rel=["']canonical["'][^>]*href=["']([^"']+)["']"""
)
_LANG = re.compile(r"""(?is)<html[^>]*\blang=["']([^"']+)["']""")
_H1 = re.compile(r"(?is)<h1\b[^>]*>(.*?)</h1>")
_VIEWPORT = re.compile(r"""(?is)<meta\s+[^>]*name=["']viewport["']""")
_GENERATOR = re.compile(
    r"""(?is)<meta\s+[^>]*name=["']generator["'][^>]*content=["']([^"']+)["']"""
)


def _utc_now() -> str:
    return (
        datetime.now(timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )


def target_url(domain_or_url: str) -> str:
    raw = normalize_domain(domain_or_url)
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw
    return f"https://{raw}/"


def _host_of(url: str) -> str:
    return (urlparse(url).hostname or "").lower()


def _assert_public_host(host: str) -> None:
    if not host:
        raise ValueError("empty host")
    try:
        infos = socket.getaddrinfo(host, None)
    except socket.gaierror as exc:
        raise ValueError(f"DNS failed for {host}: {exc}") from exc
    for info in infos:
        ip_s = info[4][0]
        try:
            ip = ipaddress.ip_address(ip_s)
        except ValueError:
            continue
        if (
            ip.is_private
            or ip.is_loopback
            or ip.is_link_local
            or ip.is_reserved
            or ip.is_multicast
        ):
            raise ValueError(f"refusing non-public target {host} → {ip}")


def _fetch(url: str, *, follow: bool = True) -> dict[str, Any]:
    req = urllib.request.Request(
        url,
        method="GET",
        headers={"User-Agent": USER_AGENT, "Accept": "text/html,*/*"},
    )
    handlers: list[Any] = []
    if follow:
        handlers.append(urllib.request.HTTPRedirectHandler())
    opener = urllib.request.build_opener(*handlers)
    try:
        with opener.open(req, timeout=TIMEOUT_S) as resp:
            body = resp.read(512_000)
            headers = {k.lower(): v for k, v in resp.headers.items()}
            return {
                "ok": True,
                "url": resp.geturl(),
                "status": int(getattr(resp, "status", 200) or 200),
                "headers": headers,
                "body": body.decode("utf-8", errors="replace"),
            }
    except urllib.error.HTTPError as exc:
        headers = {k.lower(): v for k, v in (exc.headers or {}).items()}
        body = b""
        try:
            body = exc.read(64_000)
        except Exception:
            pass
        return {
            "ok": True,
            "url": url,
            "status": int(exc.code),
            "headers": headers,
            "body": body.decode("utf-8", errors="replace"),
            "httpError": True,
        }
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "url": url, "error": str(exc)}


def _tls_info(host: str) -> dict[str, Any]:
    ctx = ssl.create_default_context()
    try:
        with socket.create_connection((host, 443), timeout=TIMEOUT_S) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as ssock:
                cert = ssock.getpeercert()
                not_after = cert.get("notAfter") if cert else None
                days = None
                if not_after:
                    try:
                        end = datetime.strptime(
                            str(not_after), "%b %d %H:%M:%S %Y %Z"
                        )
                        end = end.replace(tzinfo=timezone.utc)
                        days = (end - datetime.now(timezone.utc)).days
                    except ValueError:
                        days = None
                sans: list[str] = []
                for typ, val in cert.get("subjectAltName") or []:
                    if typ == "DNS":
                        sans.append(val)
                issuer = ""
                for part in cert.get("issuer") or ():
                    for k, v in part:
                        if k == "organizationName":
                            issuer = v
                return {
                    "ok": True,
                    "tlsVersion": ssock.version(),
                    "issuer": issuer or "—",
                    "notAfter": not_after,
                    "daysLeft": days,
                    "sans": sans,
                }
    except Exception as exc:  # noqa: BLE001
        return {"ok": False, "error": str(exc)}


def _security_headers(headers: dict[str, str]) -> dict[str, Any]:
    present: dict[str, str | None] = {}
    missing: list[str] = []
    for key in SECURITY_HEADERS:
        val = headers.get(key)
        present[key] = val
        if not val:
            missing.append(key)
    csp = (headers.get("content-security-policy") or "").lower()
    if "frame-ancestors" in csp and "x-frame-options" in missing:
        missing = [m for m in missing if m != "x-frame-options"]
    return {
        "score": f"{6 - len(missing)}/6",
        "missing": missing,
        "values": present,
    }


def _strip_tags(text: str) -> str:
    return re.sub(r"(?is)<[^>]+>", "", text).strip()


def _seo(html_body: str) -> dict[str, Any]:
    title_m = _TITLE.search(html_body)
    title = _strip_tags(title_m.group(1)) if title_m else ""
    desc_m = _META_DESC.search(html_body) or _META_DESC_ALT.search(html_body)
    desc = (desc_m.group(1) if desc_m else "").strip()
    canon_m = _CANONICAL.search(html_body)
    lang_m = _LANG.search(html_body)
    h1_m = _H1.search(html_body)
    gen_m = _GENERATOR.search(html_body)
    issues: list[str] = []
    if not title:
        issues.append("title_missing")
    if not desc:
        issues.append("meta_description_missing")
    if not canon_m:
        issues.append("canonical_missing")
    if not lang_m:
        issues.append("lang_missing")
    if not h1_m:
        issues.append("h1_missing")
    if not _VIEWPORT.search(html_body):
        issues.append("viewport_missing")
    return {
        "title": title[:120],
        "titleLen": len(title),
        "metaDescription": desc[:200] or None,
        "canonical": canon_m.group(1) if canon_m else None,
        "lang": lang_m.group(1) if lang_m else None,
        "h1": _strip_tags(h1_m.group(1))[:120] if h1_m else None,
        "viewport": bool(_VIEWPORT.search(html_body)),
        "generator": gen_m.group(1) if gen_m else None,
        "issues": issues,
    }


def _external_sources(html_body: str, page_host: str) -> list[str]:
    found: list[str] = []
    seen: set[str] = set()
    for m in _ATTR_URL.finditer(html_body):
        url = m.group(1)
        host = _host_of(url)
        if not host or host == page_host or host.endswith("." + page_host):
            continue
        if url not in seen:
            seen.add(url)
            found.append(url)
    return found[:40]


def check_url(domain_or_url: str) -> dict[str, Any]:
    """Run one static site-check. Raises ValueError for private targets."""
    url = target_url(domain_or_url)
    host = _host_of(url)
    _assert_public_host(host)

    https = _fetch(url)
    http_redirect = _fetch(f"http://{host}/", follow=True)

    tls = _tls_info(host)
    headers = (https.get("headers") or {}) if https.get("ok") else {}
    body = str(https.get("body") or "") if https.get("ok") else ""
    sec = (
        _security_headers(headers)
        if https.get("ok")
        else {
            "score": "0/6",
            "missing": list(SECURITY_HEADERS),
            "values": {},
        }
    )
    seo = _seo(body) if body else {"issues": ["no_html"]}
    externals = _external_sources(body, host) if body else []

    findings: list[str] = []
    if not https.get("ok"):
        findings.append(f"fetch_failed:{https.get('error')}")
    else:
        if int(https.get("status") or 0) >= 400:
            findings.append(f"http_status:{https.get('status')}")
        findings.extend(f"header_missing:{h}" for h in sec.get("missing") or [])
        findings.extend(f"seo:{i}" for i in (seo.get("issues") or []))
        if externals:
            findings.append(f"external_sources:{len(externals)}")
        if tls.get("ok") and tls.get("daysLeft") is not None and int(tls["daysLeft"]) < 21:
            findings.append(f"tls_expiring:{tls['daysLeft']}d")
        if not tls.get("ok"):
            findings.append(f"tls_failed:{tls.get('error')}")
        srv = headers.get("server") or ""
        if re.search(r"/\d", srv):
            findings.append("server_version_exposed")
        if headers.get("x-powered-by"):
            findings.append("x_powered_by_exposed")

    http_to_https = False
    if http_redirect.get("ok"):
        final = str(http_redirect.get("url") or "")
        http_to_https = final.startswith("https://")

    return {
        "input": domain_or_url,
        "url": https.get("url") or url,
        "host": host,
        "ok": bool(https.get("ok")) and not findings,
        "status": https.get("status"),
        "server": headers.get("server"),
        "poweredBy": headers.get("x-powered-by"),
        "httpToHttps": http_to_https,
        "tls": tls,
        "securityHeaders": sec,
        "seo": seo,
        "externalSources": externals,
        "findings": findings,
        "checkedAt": _utc_now(),
    }


def run_site_check_wave(
    *,
    workspace_ids: list[str] | None = None,
    domains: list[str] | None = None,
) -> dict[str, Any]:
    """Check all domains attached to workspaces (or an explicit domain list)."""
    results: list[dict[str, Any]] = []
    errors: list[str] = []

    if domains:
        for d in domains:
            try:
                results.append({"workspaceId": None, "check": check_url(d)})
            except Exception as exc:  # noqa: BLE001
                errors.append(f"{d}: {exc}")
                results.append(
                    {
                        "workspaceId": None,
                        "check": {
                            "input": d,
                            "ok": False,
                            "findings": [f"error:{exc}"],
                            "checkedAt": _utc_now(),
                        },
                    }
                )
    else:
        wss = (
            [get_workspace(w) for w in workspace_ids]
            if workspace_ids
            else workspaces_with_domains()
        )
        for ws in wss:
            if ws is None:
                continue
            for d in ws.domains:
                try:
                    results.append({"workspaceId": ws.id, "check": check_url(d)})
                except Exception as exc:  # noqa: BLE001
                    errors.append(f"{ws.id}/{d}: {exc}")
                    results.append(
                        {
                            "workspaceId": ws.id,
                            "check": {
                                "input": d,
                                "ok": False,
                                "findings": [f"error:{exc}"],
                                "checkedAt": _utc_now(),
                            },
                        }
                    )

    finding_n = sum(
        len((r.get("check") or {}).get("findings") or []) for r in results
    )
    payload = {
        "updatedAt": _utc_now(),
        "ok": not errors and finding_n == 0,
        "checked": len(results),
        "findingCount": finding_n,
        "errors": errors,
        "results": results,
    }
    path = site_check_latest_file()
    path.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    return payload


def load_site_check_latest() -> dict[str, Any] | None:
    path = site_check_latest_file()
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def format_site_check_brief(payload: dict[str, Any] | None) -> str:
    if not payload:
        return "Site-check: no results — run wave first."
    lines = [
        f"Site-check · {payload.get('checked', 0)} URL(s) · "
        f"findings {payload.get('findingCount', 0)} · "
        f"updated {payload.get('updatedAt')}"
    ]
    for row in payload.get("results") or []:
        chk = row.get("check") or {}
        wid = row.get("workspaceId") or "—"
        findings = chk.get("findings") or []
        mark = "ok" if not findings else f"{len(findings)} issue(s)"
        lines.append(
            f"  {wid} · {chk.get('host') or chk.get('input')} · "
            f"{chk.get('status')} · headers "
            f"{((chk.get('securityHeaders') or {}).get('score'))} · {mark}"
        )
        for f in findings[:5]:
            lines.append(f"    - {f}")
    return "\n".join(lines)
