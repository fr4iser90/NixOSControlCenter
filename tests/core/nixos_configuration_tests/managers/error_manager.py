from ..handlers.nixos_error_handler import NixOSErrorHandler
from typing import Dict
import atexit

class ErrorManager:
    """Zentraler Manager für Fehlerbehandlung"""
    
    _instance = None
    _handlers: Dict[str, NixOSErrorHandler] = {}
    
    def __new__(cls):
        if cls._instance is None:
            cls._instance = super().__new__(cls)
            atexit.register(cls._instance.save_error_reports)
        return cls._instance
    
    def get_handler(self, test_name: str) -> NixOSErrorHandler:
        """Gibt einen Error Handler für einen spezifischen Test zurück"""
        if test_name not in self._handlers:
            self._handlers[test_name] = NixOSErrorHandler()
        return self._handlers[test_name]
    
    def save_error_reports(self):
        """Speichert alle Fehlerberichte beim Beenden"""
        for test_name, handler in self._handlers.items():
            if handler.errors:
                handler.export_errors(
                    Path(f"test_results/{test_name}_errors.json")
                )