"""Fleet session: candidate host → Connect → probe → gate (install/update/ready/block)."""

from __future__ import annotations

from dataclasses import dataclass, replace

from PySide6.QtCore import QObject, QRunnable, QThreadPool, Signal, Slot

from ncc_gui.target_probe import (
    EXPECTED_CONFIG_VERSION,
    TargetProbe,
    classify_gate,
    copy_ssh_key,
    probe_target,
)
from ncc_gui.target_state import apply_env, set_active_target

# idle: local / disconnected
# candidate: remote selected, not connected
# connecting: probe in flight
# blocked | needs_install | needs_update | ready: after remote probe
SessionState = str


@dataclass(frozen=True)
class TargetSession:
    state: SessionState
    candidate: str | None  # combo selection (may differ from connected)
    connected: str | None  # active remote target, or None = this machine
    probe: TargetProbe | None
    expected_version: str = EXPECTED_CONFIG_VERSION
    message: str = ""

    @property
    def is_remote(self) -> bool:
        return bool(self.connected)

    @property
    def gate(self) -> str:
        if self.state in (
            "blocked",
            "needs_install",
            "needs_update",
            "ready",
            "connecting",
            "candidate",
            "idle",
        ):
            return self.state
        return "idle"


class _ProbeSignals(QObject):
    finished = Signal(object, object)  # host: str|None, probe: TargetProbe


class _ProbeJob(QRunnable):
    def __init__(
        self,
        host: str | None,
        signals: _ProbeSignals,
        *,
        password: str | None = None,
        install_key: bool = False,
    ) -> None:
        super().__init__()
        self._host = host
        self._signals = signals
        self._password = password
        self._install_key = install_key
        self.setAutoDelete(True)

    def run(self) -> None:
        host = self._host
        password = self._password
        if host and self._install_key and password:
            ok, err = copy_ssh_key(host, password)
            if not ok:
                probe = TargetProbe(
                    target=host,
                    reachable=False,
                    is_nixos=False,
                    arch="",
                    os_id="",
                    os_pretty="",
                    hostname="",
                    ncc_on_path=False,
                    etc_nixos_kind="missing",
                    config_version="",
                    error=err or "ssh-copy-id failed",
                    auth_required=True,
                )
                self._signals.finished.emit(host, probe)
                return
            password = None
        probe = probe_target(host, invoke_ncc=False, password=password)
        self._signals.finished.emit(host, probe)


class TargetSessionController(QObject):
    """Owns Connect/Disconnect and emits sessionChanged(TargetSession)."""

    sessionChanged = Signal(object)
    authNeeded = Signal(str, str)  # host, error detail

    def __init__(self, parent: QObject | None = None) -> None:
        super().__init__(parent)
        self._session = TargetSession(
            state="idle",
            candidate=None,
            connected=None,
            probe=None,
            message="",
        )
        self._pool = QThreadPool.globalInstance()
        self._probe_signals = _ProbeSignals()
        self._probe_signals.finished.connect(self._on_probe_finished)
        self._probe_gen = 0
        self._auth_prompt_pending = False

    def session(self) -> TargetSession:
        return self._session

    def dismiss_auth_prompt(self) -> None:
        """Allow Connect to show the auth modal again after cancel."""
        self._auth_prompt_pending = False

    def _emit(self, s: TargetSession) -> None:
        self._session = s
        self.sessionChanged.emit(s)

    def set_candidate(self, target: str | None) -> None:
        """Combo changed — do not activate remote until Connect."""
        want = (target or "").strip() or None
        cur = self._session
        if want is None:
            # User chose This machine / Clear — forget reconnect candidate on disk
            set_active_target(None)
            if cur.connected:
                self.disconnect_target()
                return
            if cur.connected is None and cur.candidate is None and cur.state == "idle":
                if cur.message:
                    self._emit(replace(cur, message="", probe=None))
                return
            self._activate_local(probe=False)
            return
        if cur.connected and cur.connected == want and cur.state in (
            "ready",
            "needs_install",
            "needs_update",
            "blocked",
        ):
            self._emit(replace(cur, candidate=want))
            return
        apply_env(None)
        self._emit(
            TargetSession(
                state="candidate",
                candidate=want,
                connected=None,
                probe=None,
                message=f"Selected {want} — press Connect",
            )
        )

    def connect_target(self, target: str | None = None) -> TargetSession:
        """Start probe (async for remote). Returns current/connecting session."""
        host = (target if target is not None else self._session.candidate) or None
        host = (host or "").strip() or None
        if host is None:
            return self._activate_local(probe=False)
        return self._start_probe(host)

    def connect_with_password(
        self, host: str, password: str, *, install_key: bool = False
    ) -> TargetSession:
        """Retry Connect after auth modal (password probe and/or ssh-copy-id)."""
        host = (host or "").strip()
        if not host or not password:
            return self._session
        return self._start_probe(host, password=password, install_key=install_key)

    def _start_probe(
        self,
        host: str,
        *,
        password: str | None = None,
        install_key: bool = False,
    ) -> TargetSession:
        self._probe_gen += 1
        gen = self._probe_gen
        self._auth_prompt_pending = False
        label = f"Connecting to {host}…"
        if install_key:
            label = f"Installing SSH key on {host}…"
        elif password:
            label = f"Authenticating to {host}…"
        self._emit(
            TargetSession(
                state="connecting",
                candidate=host,
                connected=None,
                probe=None,
                message=label,
            )
        )
        self._pending_gen = gen
        self._pending_host = host
        job = _ProbeJob(
            host,
            self._probe_signals,
            password=password,
            install_key=install_key,
        )
        self._pool.start(job)
        return self._session

    @Slot(object, object)
    def _on_probe_finished(self, host: object, probe: object) -> None:
        if not isinstance(probe, TargetProbe):
            return
        want = host if isinstance(host, str) else None
        if getattr(self, "_pending_host", None) != want:
            return
        if getattr(self, "_pending_gen", 0) != self._probe_gen:
            return

        if probe.auth_required and want:
            apply_env(None)
            detail = probe.error or "Permission denied"
            self._emit(
                TargetSession(
                    state="candidate",
                    candidate=want,
                    connected=None,
                    probe=probe,
                    message=f"{want}: authentication required",
                )
            )
            if not self._auth_prompt_pending:
                self._auth_prompt_pending = True
                self.authNeeded.emit(want, detail)
            return

        gate = classify_gate(probe)
        msg = _message_for(gate, probe, want)

        if not probe.reachable or want is None:
            apply_env(None)
            self._emit(
                TargetSession(
                    state="blocked",
                    candidate=want,
                    connected=None,
                    probe=probe,
                    message=msg,
                )
            )
            return

        set_active_target(want)
        self._emit(
            TargetSession(
                state=gate,
                candidate=want,
                connected=want,
                probe=probe,
                message=msg,
            )
        )

    def bootstrap_from_disk(self) -> None:
        """Startup: instant. No local probe — this machine is just idle."""
        from ncc_gui.target_state import saved_target_candidate

        saved = saved_target_candidate()
        apply_env(None)
        if saved:
            self._emit(
                TargetSession(
                    state="candidate",
                    candidate=saved,
                    connected=None,
                    probe=None,
                    message=f"Saved {saved} — press Connect (not linked yet)",
                )
            )
            return
        self._emit(
            TargetSession(
                state="idle",
                candidate=None,
                connected=None,
                probe=None,
                message="",
            )
        )

    def disconnect_target(self) -> TargetSession:
        """Drop remote session and forget the saved reconnect candidate."""
        self._probe_gen += 1
        self._auth_prompt_pending = False
        set_active_target(None)
        apply_env(None)
        self._emit(
            TargetSession(
                state="idle",
                candidate=None,
                connected=None,
                probe=None,
                message="",
            )
        )
        return self._session

    def refresh(self) -> TargetSession:
        if self._session.connected:
            return self.connect_target(self._session.connected)
        return self._activate_local(probe=True)

    def _activate_local(self, *, probe: bool) -> TargetSession:
        apply_env(None)
        if not probe:
            s = TargetSession(
                state="idle",
                candidate=None,
                connected=None,
                probe=None,
                message="",
            )
            self._emit(s)
            return s
        p = probe_target(None, invoke_ncc=False)
        gate = classify_gate(p)
        if gate in ("needs_install", "needs_update", "blocked"):
            state = gate
            msg = _message_for(gate, p, None)
        else:
            state = "idle"
            msg = ""
        s = TargetSession(
            state=state,
            candidate=None,
            connected=None,
            probe=p if state != "idle" else None,
            message=msg,
        )
        self._emit(s)
        return s


def _message_for(gate: str, probe: TargetProbe, host: str | None) -> str:
    from ncc_gui.session_ux import local_hostname

    local = host is None
    where = host or "This machine"
    arch = probe.platform_linux or probe.arch or "?"
    if gate == "blocked":
        if probe.auth_required:
            return f"{where}: authentication required (password or SSH key)"
        if not probe.reachable:
            # Explicit: fail does not switch scope — still LOCAL.
            err = probe.error or "SSH failed"
            if local:
                return f"unreachable ({err})"
            return (
                f"Still on LOCAL ({local_hostname()}). "
                f"Cannot reach {where}: {err}"
            )
        if not probe.arch_supported:
            return f"{where}: unsupported architecture ({probe.arch})"
        if not probe.is_nixos:
            return f"{where}: not NixOS ({probe.os_pretty or probe.os_id})"
        return f"{where}: blocked ({probe.error or 'unsupported'})"
    if gate == "needs_install":
        return f"{where} · {arch} · no usable NCC — open Install"
    if gate == "needs_update":
        have = probe.config_version or "?"
        return (
            f"{where} · {arch} · NCC config {have} "
            f"→ update to {EXPECTED_CONFIG_VERSION}"
        )
    ver = probe.config_version or EXPECTED_CONFIG_VERSION
    if local:
        return ""
    return f"Connected · {where} · {arch} · NCC {ver}"


_controller: TargetSessionController | None = None


def session_controller() -> TargetSessionController:
    global _controller
    if _controller is None:
        _controller = TargetSessionController()
    return _controller


def current_session() -> TargetSession:
    return session_controller().session()
