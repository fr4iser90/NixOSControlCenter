"""Engine page helpers only — rich domain pages live in each module’s ui/gui/."""

from ncc_gui.pages.base import DomainActionsPage
from ncc_gui.pages.generic import GenericDomainPage
from ncc_gui.pages.resolve import create_page_for

__all__ = [
    "DomainActionsPage",
    "GenericDomainPage",
    "create_page_for",
]
