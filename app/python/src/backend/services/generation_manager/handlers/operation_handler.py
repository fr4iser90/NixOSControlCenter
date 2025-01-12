from typing import Dict, Any
import subprocess
import logging

logger = logging.getLogger(__name__)

class GenerationOperationHandler:
    def rename(self, generation: Dict[str, Any], new_name: str) -> bool:
        """Handle generation rename operation."""
        try:
            # Nutze das existierende NixOS-Script
            cmd = [
                "rename-boot-entries",
                str(generation['number']),
                new_name
            ]
            
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True
            )

            if result.returncode != 0:
                logger.error(f"Failed to rename: {result.stderr}")
                return False
                
            logger.info(f"Successfully renamed generation {generation['number']} to {new_name}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to rename generation: {e}")
            return False

    def lock(self, generation: Dict[str, Any]) -> bool:
        """Handle generation lock operation."""
        pass

    def analyze(self, generation: Dict[str, Any]) -> Dict[str, Any]:
        """Handle generation analysis operation."""
        pass

    def delete(self, generation: Dict[str, Any]) -> bool:
        """Handle generation delete operation."""
        pass 