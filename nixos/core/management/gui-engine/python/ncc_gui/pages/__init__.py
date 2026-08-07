"""Optional rich pages live as ncc_gui.pages.<domain_id>; everything else is generic."""

from ncc_gui.pages.base import DomainActionsPage
from ncc_gui.pages.generic import GenericDomainPage
from ncc_gui.pages.lock import LockPage
from ncc_gui.pages.network import NetworkPage
from ncc_gui.pages.packages import PackagesPage
from ncc_gui.pages.resolve import create_page_for

__all__ = [
    "DomainActionsPage",
    "GenericDomainPage",
    "PackagesPage",
    "NetworkPage",
    "LockPage",
    "create_page_for",
]
