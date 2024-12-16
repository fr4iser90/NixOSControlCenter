## Path: src/frontend/core/state_manager.py

from typing import Any, Dict, Optional
import logging
from .persistence_handler import PersistenceHandler

logger = logging.getLogger(__name__)

class StateManager:
    def __init__(self):
        """Initialize the state manager."""
        self.states: Dict[str, Any] = {}
        self.persistence = PersistenceHandler()
        self._load_initial_states()

    def _load_initial_states(self) -> None:
        """Load all saved states during initialization."""
        try:
            self.states = self.persistence.load_all()
            logger.debug("Initial states loaded successfully")
        except Exception as e:
            logger.error(f"Failed to load initial states: {e}")

    def save_state(self, label: str, state: Any) -> bool:
        """
        Save state for a specific view.
        
        Args:
            label: The identifier for the state
            state: The state data to save
            
        Returns:
            bool: True if save was successful
        """
        try:
            self.states[label] = state
            success = self.persistence.save(label, state)
            if success:
                logger.debug(f"State saved for {label}")
            return success
        except Exception as e:
            logger.error(f"Failed to save state for {label}: {e}")
            return False

    def get_state(self, label: str, default: Any = None) -> Any:
        """
        Retrieve state for a specific view.
        
        Args:
            label: The identifier for the state
            default: Default value if state doesn't exist
            
        Returns:
            The state or default value
        """
        try:
            if label not in self.states:
                self.states[label] = self.persistence.load(label)
            return self.states.get(label, default)
        except Exception as e:
            logger.error(f"Failed to get state for {label}: {e}")
            return default

    def update_state(self, label: str, updates: Dict[str, Any]) -> bool:
        """
        Update specific fields in a state.
        
        Args:
            label: The identifier for the state
            updates: Dictionary of fields to update
            
        Returns:
            bool: True if update was successful
        """
        try:
            current_state = self.get_state(label, {})
            if isinstance(current_state, dict):
                current_state.update(updates)
                return self.save_state(label, current_state)
            return False
        except Exception as e:
            logger.error(f"Failed to update state for {label}: {e}")
            return False

    def delete_state(self, label: str) -> bool:
        """
        Delete a specific state.
        
        Args:
            label: The identifier for the state to delete
            
        Returns:
            bool: True if deletion was successful
        """
        try:
            if label in self.states:
                del self.states[label]
            return self.persistence.delete(label)
        except Exception as e:
            logger.error(f"Failed to delete state for {label}: {e}")
            return False

    def clear_all_states(self) -> bool:
        """
        Clear all states.
        
        Returns:
            bool: True if clearing was successful
        """
        try:
            self.states.clear()
            return self.persistence.clear_all()
        except Exception as e:
            logger.error(f"Failed to clear all states: {e}")
            return False