#!/usr/bin/env python3
"""Single-question GUI dialogs for install prompts (fallback mid-flow).

Usage:
  gui_ask.py text TITLE PROMPT [DEFAULT]
  gui_ask.py yesno TITLE PROMPT [y|n]
  gui_ask.py choice TITLE PROMPT OPT1|OPT2|... [DEFAULT]
  gui_ask.py password TITLE PROMPT [HINT]
"""

from __future__ import annotations

import sys
import tkinter as tk
from tkinter import messagebox, ttk
from typing import List, Optional


def _style(root: tk.Tk) -> None:
    root.configure(bg="#1a1d23")
    style = ttk.Style(root)
    try:
        style.theme_use("clam")
    except tk.TclError:
        pass
    bg, fg, card = "#1a1d23", "#e8eaed", "#242830"
    style.configure(".", background=bg, foreground=fg, fieldbackground=card)
    style.configure("TFrame", background=bg)
    style.configure("TLabel", background=bg, foreground=fg, font=("Sans", 11))
    style.configure("Title.TLabel", background=bg, foreground=fg, font=("Sans", 14, "bold"))
    style.configure("Sub.TLabel", background=bg, foreground="#9aa0a6", font=("Sans", 10))
    style.configure("TButton", font=("Sans", 10), padding=8)
    style.configure("TRadiobutton", background=bg, foreground=fg, font=("Sans", 11))
    style.configure("TEntry", fieldbackground=card, foreground=fg)


class AskApp(tk.Tk):
    def __init__(self, title: str, prompt: str) -> None:
        super().__init__()
        self.title(title)
        self.geometry("520x280")
        self.minsize(420, 220)
        self.result: Optional[str] = None
        _style(self)
        self.protocol("WM_DELETE_WINDOW", self._cancel)
        ttk.Label(self, text=title, style="Title.TLabel").pack(anchor="w", padx=20, pady=(16, 4))
        ttk.Label(self, text=prompt, style="Sub.TLabel", wraplength=460).pack(anchor="w", padx=20, pady=(0, 12))
        self.body = ttk.Frame(self)
        self.body.pack(fill="both", expand=True, padx=20)
        nav = ttk.Frame(self)
        nav.pack(fill="x", padx=20, pady=16)
        ttk.Button(nav, text="Cancel", command=self._cancel).pack(side="right", padx=(8, 0))
        ttk.Button(nav, text="OK", command=self._ok).pack(side="right")
        self.bind("<Return>", lambda _e: self._ok())
        self.bind("<Escape>", lambda _e: self._cancel())

    def _ok(self) -> None:
        self.destroy()

    def _cancel(self) -> None:
        self.result = None
        self.destroy()


def ask_text(title: str, prompt: str, default: str = "") -> Optional[str]:
    app = AskApp(title, prompt)
    var = tk.StringVar(value=default)
    entry = ttk.Entry(app.body, textvariable=var, width=48)
    entry.pack(fill="x", pady=8)
    entry.focus_set()

    def _ok() -> None:
        app.result = var.get().strip() or default
        if not app.result:
            messagebox.showinfo("Required", "Please enter a value.")
            return
        app.destroy()

    app._ok = _ok  # type: ignore[method-assign]
    app.mainloop()
    return app.result


def ask_yesno(title: str, prompt: str, default: str = "y") -> Optional[str]:
    app = AskApp(title, prompt)
    default_norm = "y" if default.lower() in ("y", "yes", "true") else "n"
    var = tk.StringVar(value=default_norm)
    ttk.Radiobutton(app.body, text="Yes", value="y", variable=var).pack(anchor="w", pady=4)
    ttk.Radiobutton(app.body, text="No", value="n", variable=var).pack(anchor="w", pady=4)

    def _ok() -> None:
        app.result = var.get()
        app.destroy()

    app._ok = _ok  # type: ignore[method-assign]
    app.mainloop()
    return app.result


def ask_choice(title: str, prompt: str, options: List[str], default: str = "") -> Optional[str]:
    app = AskApp(title, prompt)
    app.geometry("520x360")
    var = tk.StringVar(value=default if default in options else (options[0] if options else ""))
    for opt in options:
        ttk.Radiobutton(app.body, text=opt, value=opt, variable=var).pack(anchor="w", pady=3)

    def _ok() -> None:
        app.result = var.get()
        app.destroy()

    app._ok = _ok  # type: ignore[method-assign]
    app.mainloop()
    return app.result


def ask_password(title: str, prompt: str, hint: str = "") -> Optional[str]:
    app = AskApp(title, prompt + (("\n" + hint) if hint else ""))
    app.geometry("520x320")
    p1 = tk.StringVar()
    p2 = tk.StringVar()
    ttk.Label(app.body, text="Password").pack(anchor="w")
    e1 = ttk.Entry(app.body, textvariable=p1, show="•", width=48)
    e1.pack(fill="x", pady=(0, 8))
    ttk.Label(app.body, text="Confirm").pack(anchor="w")
    ttk.Entry(app.body, textvariable=p2, show="•", width=48).pack(fill="x", pady=(0, 8))
    if hint:
        ttk.Label(app.body, text="Leave empty to use the suggested/random password.", style="Sub.TLabel").pack(
            anchor="w"
        )
    e1.focus_set()

    def _ok() -> None:
        a, b = p1.get(), p2.get()
        if not a and not b:
            # empty = accept random/default (caller handles)
            app.result = ""
            app.destroy()
            return
        if len(a) < 8:
            messagebox.showerror("Too short", "Password must be at least 8 characters.")
            return
        if a != b:
            messagebox.showerror("Mismatch", "Passwords do not match.")
            return
        app.result = a
        app.destroy()

    app._ok = _ok  # type: ignore[method-assign]
    app.mainloop()
    return app.result


def main(argv: List[str]) -> int:
    if len(argv) < 3:
        print("Usage: gui_ask.py TYPE TITLE PROMPT [args...]", file=sys.stderr)
        return 2
    ask_type, title, prompt = argv[0], argv[1], argv[2]
    rest = argv[3:]

    if not (__import__("os").environ.get("DISPLAY") or __import__("os").environ.get("WAYLAND_DISPLAY")):
        print("No graphical display", file=sys.stderr)
        return 2

    try:
        if ask_type == "text":
            default = rest[0] if rest else ""
            result = ask_text(title, prompt, default)
        elif ask_type == "yesno":
            default = rest[0] if rest else "y"
            result = ask_yesno(title, prompt, default)
        elif ask_type == "choice":
            opts = (rest[0] if rest else "").split("|")
            opts = [o for o in opts if o]
            default = rest[1] if len(rest) > 1 else ""
            result = ask_choice(title, prompt, opts, default)
        elif ask_type == "password":
            hint = rest[0] if rest else ""
            result = ask_password(title, prompt, hint)
        else:
            print(f"Unknown ask type: {ask_type}", file=sys.stderr)
            return 2
    except tk.TclError as exc:
        print(f"GUI failed: {exc}", file=sys.stderr)
        return 2

    if result is None:
        return 1
    print(result)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
