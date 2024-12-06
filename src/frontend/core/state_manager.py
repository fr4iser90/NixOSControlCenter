## Path: src/frontend/core/state_manager.py

class StateManager:
    def __init__(self):
        self.states = {}

    def save_state(self, label, state):
        """Save the state for a specific view."""
        self.states[label] = state

    def get_state(self, label):
        """Retrieve the state for a specific view."""
        return self.states.get(label, None)