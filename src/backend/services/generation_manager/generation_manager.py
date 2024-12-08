## Path: src/backend/services/generation_manager.py

import subprocess
import logging
from typing import List, Dict, Any
from datetime import datetime
import json
import os
from .handlers.system_handler import SystemGenerationHandler
from .handlers.flake_handler import FlakeGenerationHandler
from .handlers.legacy_handler import LegacyGenerationHandler
from .handlers.operation_handler import GenerationOperationHandler

# Logger-Konfiguration
logger = logging.getLogger(__name__)

class GenerationManager:
    """Handles generation-related functionality in NixOS."""

    def __init__(self, debug_mode: bool = False):
        self.system_handler = SystemGenerationHandler()
        self.flake_handler = FlakeGenerationHandler()
        self.legacy_handler = LegacyGenerationHandler()
        self.operation_handler = GenerationOperationHandler()
        
        if debug_mode:
            logger.setLevel(logging.DEBUG)

    def get_generations(self) -> List[Dict[str, Any]]:
        """Get all generations from all handlers."""
        generations = []
        generations.extend(self.system_handler.get_generations())
        generations.extend(self.flake_handler.get_generations())
        generations.extend(self.legacy_handler.get_generations())
        return generations

    def rename_generation(self, generation: Dict[str, Any], new_name: str) -> bool:
        """Rename a generation using the appropriate handler."""
        return self.operation_handler.rename(generation, new_name)

# Example usage:
manager = GenerationManager()
generations = manager.get_generations()
print(generations)
