"""The credential a ``gh`` invocation carries, and the boundary kept around it.

``gh`` reads ``GH_TOKEN`` before it reads any config file, and a schedule has no terminal to run
``gh auth login`` in, so the only credential an unattended GitHub verb can hold is one the run
publishes for itself. NCC already stores that credential — the templates declare
``requiresSecrets: ["github_token"]`` and the GitHub MCP server receives the same secret as
``GITHUB_PERSONAL_ACCESS_TOKEN`` — but nothing ever handed it to the CLI. A scheduled
``ncc ai workflow pr`` therefore asked ``gh`` for a login no timer can produce while the token sat
in ``secrets.json`` two directories away, and the run reported it as gh's own exit code.

Built per invocation and never into ``os.environ``: a GH_TOKEN exported here would reach every
child the run later spawns — an allowlisted shell command, the external harness, a git hook —
and hand a GitHub credential to a capability that was never granted one.

Precedence, narrowest first: an ambient ``GH_TOKEN``/``GITHUB_TOKEN`` (the unit said so out loud,
through ``agent.runAsUser``'s environment or a systemd ``Environment=``) is left exactly as it is;
otherwise the named secret is used. With neither, ``gh`` falls back to the interactive
``gh auth login`` state of the account the run carries, which stays the documented path for a run
a human set up by hand.
"""

from __future__ import annotations

import os

from core.store.secrets import get_secret_value

#: The secret every GitHub-capable agent template already names.
GH_SECRET_NAME = "github_token"


def gh_env() -> dict[str, str]:
    """Environment for one ``gh`` invocation: the ambient env plus ``GH_TOKEN`` when resolvable.

    The returned dict is for a single ``subprocess.run(env=...)``. Callers must not store it, and
    must not merge it back into ``os.environ`` — that is the leak this function exists to avoid.
    """
    env = dict(os.environ)
    if env.get("GH_TOKEN") or env.get("GITHUB_TOKEN"):
        return env
    token = get_secret_value(GH_SECRET_NAME)
    if token:
        env["GH_TOKEN"] = token
    return env
