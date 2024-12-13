from typing import List, Dict, Any
import subprocess
import logging
import re

logger = logging.getLogger(__name__)

class FlakeGenerationHandler:
    def get_generations(self) -> List[Dict[str, Any]]:
        """Get flake generations."""
        try:
            result = subprocess.run(
                ["nix", "profile", "history", "--profile", "/nix/var/nix/profiles/system"],
                capture_output=True,
                text=True
            )
            
            if"No changes" in result.stdout:
                logger.debug("No flake generations found")
                return []
            
            generations = []
            lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
            
            for line in lines:
                # Skip header and empty lines
                if any(line.startswith(x) for x in ['Version', 'No changes']):
                    continue
                    
                generation = self._parse_generation_line(line)
                if generation:
                    generation['type'] = 'flake'
                    generations.append(generation)
            
            return generations
            
        except Exception as e:
            logger.error(f"Failed to get flake generations: {e}")
            return []

    def _parse_generation_line(self, line: str) -> Dict[str, Any]:
        """Parse a generation line from nix profile output."""
        try:
            # Erwartetes Format: "123   name   /nix/store/..."
            pattern = r'(\d+)\s+(\S+)\s+(/nix/store/\S+)'
            match = re.match(pattern, line)
            
            if not match:
                # Nur Debug-Log wenn es keine "No changes" Zeile ist
                if not "No changes" in line:
                    logger.debug(f"Line does not match expected format: {line}")
                return {}
                
            return {
                'number': int(match.group(1)),
                'name': match.group(2),
                'store_path': match.group(3)
            }
            
        except Exception as e:
            logger.error(f"Failed to parse generation line '{line}': {e}")
            return {}

    def _get_flake_info(self) -> Dict[str, Any]:
        """Get additional flake information if available."""
        try:
            result = subprocess.run(
                ["nix", "flake", "info"],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                return {'flake_info': result.stdout}
            return {}
        except Exception as e:
            logger.error(f"Failed to get flake info: {e}")
            return {}

    def _debug_output(self, output: str) -> None:
        """Debug helper to print raw command output."""
        logger.debug("Raw command output:")
        for line in output.splitlines():
            logger.debug(f"Line: '{line}'")