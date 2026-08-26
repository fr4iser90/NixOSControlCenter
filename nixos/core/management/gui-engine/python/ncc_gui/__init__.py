"""NCC shared Qt/PySide6 GUI engine (chrome, dialogs, page kit)."""

__version__ = "0.2.0"
__all__ = ["DomainPage", "PageScaffold"]


def __getattr__(name: str):
    if name == "DomainPage":
        from ncc_gui.scaffold import DomainPage

        return DomainPage
    if name == "PageScaffold":
        from ncc_gui.scaffold import PageScaffold

        return PageScaffold
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
