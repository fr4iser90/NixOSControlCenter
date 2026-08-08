"""Desktop — DomainPage kit (Settings → Actions → Activity)."""

from __future__ import annotations

from PySide6.QtWidgets import QCheckBox, QComboBox

from ncc_gui.dialogs import confirm, info
from ncc_gui.remote import run_ncc
from ncc_gui.scaffold import DomainPage


def _parse_kv(text: str) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or "=" not in line:
            continue
        k, v = line.split("=", 1)
        out[k.strip()] = v.strip()
    return out


class DesktopPage(DomainPage):
    def __init__(self, parent=None) -> None:
        super().__init__(
            "Desktop",
            "Set desktop environment, login screen, display server, and theme. "
            "Apply writes the config; rebuild makes it active. "
            "Changing DE, login, or Wayland/X11 usually needs a re-login.",
            parent=parent,
        )

        form = self.add_form_block("Settings")

        self.env = QComboBox()
        for v, lab in (
            ("plasma", "Plasma (KDE)"),
            ("gnome", "GNOME"),
            ("xfce", "XFCE"),
        ):
            self.env.addItem(lab, v)
        form.addRow("Desktop environment", self.env)

        self.manager = QComboBox()
        for v, lab in (
            ("sddm", "SDDM"),
            ("gdm", "GDM"),
            ("lightdm", "LightDM"),
        ):
            self.manager.addItem(lab, v)
        form.addRow("Login screen", self.manager)

        self.server = QComboBox()
        for v, lab in (
            ("wayland", "Wayland"),
            ("x11", "X11"),
            ("hybrid", "Hybrid"),
        ):
            self.server.addItem(lab, v)
        form.addRow("Display server", self.server)

        self.dark = QComboBox()
        self.dark.addItem("Dark", "true")
        self.dark.addItem("Light", "false")
        form.addRow("Theme", self.dark)

        self.enable = QCheckBox("Desktop module enabled")
        self.enable.setChecked(True)
        form.addRow("", self.enable)

        self.add_actions_hint("Apply writes system settings. You may be asked to confirm.")
        self.do_rebuild = QCheckBox("Rebuild & switch after apply")
        self.do_rebuild.setChecked(True)
        self.add_actions_widget(self.do_rebuild)
        self.add_action("Apply", self._apply, primary=True)
        self.add_action("Reload", self.reload)

        self.env.currentIndexChanged.connect(self._sync_manager_hint)
        self.reload()

    def _set_combo(self, combo: QComboBox, value: str) -> None:
        for i in range(combo.count()):
            if combo.itemData(i) == value:
                combo.setCurrentIndex(i)
                return

    def _sync_manager_hint(self) -> None:
        env = self.env.currentData()
        if env == "gnome":
            self._set_combo(self.manager, "gdm")
        elif env == "plasma":
            self._set_combo(self.manager, "sddm")

    def reload(self) -> None:
        proc = run_ncc("desktop", "status")
        kv = _parse_kv(proc.stdout or "")
        self._set_combo(self.env, kv.get("environment", "plasma"))
        self._set_combo(self.manager, kv.get("display.manager", "sddm"))
        self._set_combo(self.server, kv.get("display.server", "wayland"))
        dark = kv.get("theme.dark", "true")
        self._set_combo(self.dark, "true" if dark == "true" else "false")
        self.enable.setChecked(kv.get("enable", "true") == "true")
        if proc.returncode != 0:
            from ncc_gui.ansi import strip_ansi

            self.log_append(
                "• Reload failed\n"
                + strip_ansi(((proc.stdout or "") + (proc.stderr or "")).strip())
                + "\n"
            )

    def _apply(self) -> None:
        env = str(self.env.currentData())
        mgr = str(self.manager.currentData())
        server = str(self.server.currentData())
        dark = str(self.dark.currentData())
        enable = "true" if self.enable.isChecked() else "false"
        rebuild = self.do_rebuild.isChecked()

        summary = (
            f"Environment: {self.env.currentText()}\n"
            f"Login: {self.manager.currentText()}\n"
            f"Display: {self.server.currentText()}\n"
            f"Theme: {self.dark.currentText()}\n\n"
        )
        if rebuild:
            summary += (
                "Write config and rebuild switch.\n"
                "Re-login (or reboot) if DE / login / display server changed."
            )
        else:
            summary += "Write config only — rebuild later under System."

        if not confirm(self, "Apply desktop settings", summary):
            return

        args = [
            "desktop",
            "set",
            f"enable={enable}",
            f"environment={env}",
            f"manager={mgr}",
            f"server={server}",
            f"session={env}",
            f"dark={dark}",
        ]
        if rebuild:
            args.append("--rebuild")

        def _done(code: int) -> None:
            if code == 0:
                info(
                    self,
                    "Apply",
                    "Done. Re-login or reboot if you changed DE / login / display server.",
                )
                self.reload()

        self.run_ncc_root(args, label="Apply", on_done=_done)


def create_page() -> DesktopPage:
    return DesktopPage()


Page = DesktopPage
