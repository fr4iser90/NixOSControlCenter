# Macht die Klassen nach außen verfügbar
from .state_manager import StateManager
from .persistence_handler import PersistenceHandler

# Optional: Versionierung
__version__ = '0.1.0'

# Optional: Standardinstanz erstellen
default_state_manager = StateManager() 