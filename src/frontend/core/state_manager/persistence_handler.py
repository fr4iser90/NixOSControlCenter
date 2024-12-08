import json
import os
import logging
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)

class PersistenceHandler:
    def __init__(self):
        """Initialize the persistence handler."""
        self.state_dir = os.path.join(os.path.expanduser("~"), ".config", "nixos-control-center")
        self.state_file = os.path.join(self.state_dir, "app_states.json")
        self._ensure_state_dir()

    def _ensure_state_dir(self) -> None:
        """Ensure the state directory exists."""
        try:
            os.makedirs(self.state_dir, exist_ok=True)
            logger.debug(f"State directory ensured at: {self.state_dir}")
        except Exception as e:
            logger.error(f"Failed to create state directory: {e}")

    def save(self, label: str, state: Any) -> bool:
        """
        Persist state to disk.
        
        Args:
            label: The identifier for the state
            state: The state data to save
            
        Returns:
            bool: True if save was successful, False otherwise
        """
        try:
            current_states = self.load_all()
            current_states[label] = state
            
            with open(self.state_file, 'w') as f:
                json.dump(current_states, f, indent=2)
            
            logger.debug(f"State saved successfully for: {label}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to save state for {label}: {e}")
            return False

    def load(self, label: str) -> Optional[Any]:
        """
        Load state from disk.
        
        Args:
            label: The identifier for the state to load
            
        Returns:
            The loaded state or None if not found
        """
        try:
            states = self.load_all()
            state = states.get(label)
            logger.debug(f"State loaded for: {label}")
            return state
            
        except Exception as e:
            logger.error(f"Failed to load state for {label}: {e}")
            return None

    def load_all(self) -> Dict[str, Any]:
        """
        Load all states from disk.
        
        Returns:
            Dict containing all saved states
        """
        try:
            if not os.path.exists(self.state_file):
                return {}
                
            with open(self.state_file, 'r') as f:
                return json.load(f)
                
        except Exception as e:
            logger.error(f"Failed to load states: {e}")
            return {}

    def delete(self, label: str) -> bool:
        """
        Delete a specific state.
        
        Args:
            label: The identifier for the state to delete
            
        Returns:
            bool: True if deletion was successful, False otherwise
        """
        try:
            states = self.load_all()
            if label in states:
                del states[label]
                with open(self.state_file, 'w') as f:
                    json.dump(states, f, indent=2)
                logger.debug(f"State deleted for: {label}")
                return True
            return False
            
        except Exception as e:
            logger.error(f"Failed to delete state for {label}: {e}")
            return False

    def clear_all(self) -> bool:
        """
        Clear all saved states.
        
        Returns:
            bool: True if clearing was successful, False otherwise
        """
        try:
            if os.path.exists(self.state_file):
                os.remove(self.state_file)
            logger.debug("All states cleared")
            return True
            
        except Exception as e:
            logger.error(f"Failed to clear states: {e}")
            return False