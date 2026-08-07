"""Optional rich pages live as ncc_gui.pages.<domain_id>; everything else is generic."""

from ncc_gui.pages.base import DomainActionsPage
from ncc_gui.pages.desktop import DesktopPage
from ncc_gui.pages.generic import GenericDomainPage
from ncc_gui.pages.homelab import HomelabPage
from ncc_gui.pages.lock import LockPage
from ncc_gui.pages.network import NetworkPage
from ncc_gui.pages.packages import PackagesPage
from ncc_gui.pages.resolve import create_page_for
from ncc_gui.pages.ssh import SshPage
from ncc_gui.pages.user import UserPage
from ncc_gui.pages.vm import VmPage

__all__ = [
    "DomainActionsPage",
    "GenericDomainPage",
    "PackagesPage",
    "NetworkPage",
    "LockPage",
    "SshPage",
    "HomelabPage",
    "VmPage",
    "DesktopPage",
    "UserPage",
    "create_page_for",
]
