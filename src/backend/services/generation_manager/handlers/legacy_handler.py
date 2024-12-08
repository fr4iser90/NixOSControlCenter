from typing import List, Dict, Any
import subprocess
import logging

logger = logging.getLogger(__name__)

class LegacyGenerationHandler:
    def get_generations(self) -> List[Dict[str, Any]]:
        """Get legacy generations."""
        try:
            result = subprocess.run(
                ["nix-env", "--list-generations"],
                capture_output=True,
                text=True
            )
            
            generations = []
            for line in result.stdout.splitlines():
                if line.strip():
                    generation = self._parse_generation_line(line)
                    if generation:
                        generation['type'] = 'legacy'
                        generations.append(generation)
            
            return generations
            
        except Exception as e:
            logger.error(f"Failed to get legacy generations: {e}")
            return []

    def _parse_generation_line(self, line: str) -> Dict[str, Any]:
        """Parse a generation line from nix-env output."""
        try:
            parts = line.strip().split()
            return {
                'number': int(parts[0]),
                'date': ' '.join(parts[1:3]),
                'status': parts[3] if len(parts) > 3 else ''
            }
        except Exception as e:
            logger.error(f"Failed to parse generation line: {e}")
            return {} 