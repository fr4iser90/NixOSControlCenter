from ncc_gui.pages.base import DomainActionsPage


def SystemPage(parent=None):
    return DomainActionsPage(
        "system",
        "System",
        [
            ("System report", ("report",)),
            ("Check versions", ("check-versions",)),
            ("Config layout", ("config-layout", "detect")),
            ("Validate config", ("validate-config",)),
            ("Allow unfree packages", ("allow-unfree",)),
            ("Check release", ("check-release",)),
            ("Update channels", ("update-channels",)),
            ("Update (preview)", ("update", "--dry-run")),
            ("Rebuild now", ("build", "switch")),
            ("Update & rebuild", ("update", "-y")),
        ],
        subtitle="Keep NixOS up to date and check system health.",
        confirm_labels=(
            "Rebuild now",
            "Update & rebuild",
            "Update channels",
            "Allow unfree packages",
        ),
        parent=parent,
    )


def create_page(parent=None):
    return SystemPage(parent)
