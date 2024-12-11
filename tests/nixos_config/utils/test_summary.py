# tests/nixos_config/utils/test_summary.py
from pathlib import Path
from datetime import datetime
import json

class TestSummary:
    def __init__(self):
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'total_tests': 0,
            'failed_tests': 0,
            'passed_tests': 0,
            'failures': [],
            'system_info': self._get_system_info()
        }

    def _get_system_info(self):
        """Sammelt System-Informationen"""
        import platform
        import os
        return {
            'platform': platform.platform(),
            'nixos_version': self._get_nixos_version(),
            'hostname': platform.node(),
            'user': os.getenv('USER')
        }

    def _get_nixos_version(self):
        """Holt NixOS Version"""
        try:
            with open('/etc/os-release', 'r') as f:
                for line in f:
                    if line.startswith('VERSION='):
                        return line.split('=')[1].strip().strip('"')
        except:
            return "Unknown"
        return "Unknown"

    def add_failure(self, test_name: str, error: str, config: str = None):
        """Fügt einen Testfehler hinzu"""
        self.results['failures'].append({
            'test': test_name,
            'error': error,
            'config': config
        })
        self.results['failed_tests'] += 1

    def add_success(self, test_name: str):
        """Fügt einen erfolgreichen Test hinzu"""
        self.results['passed_tests'] += 1

    def finalize(self, output_dir: str = "tests/logs"):
        """Erstellt eine Zusammenfassung"""
        self.results['total_tests'] = (
            self.results['passed_tests'] + self.results['failed_tests']
        )
        
        # Speichere JSON-Report
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        
        with open(output_path / 'test_summary.json', 'w') as f:
            json.dump(self.results, f, indent=2)

        # Erstelle menschenlesbaren Report
        report = self._generate_readable_report()
        with open(output_path / 'test_summary.txt', 'w') as f:
            f.write(report)
        
        print("\n" + "="*50)
        print("Test-Zusammenfassung:")
        print("="*50)
        print(report)

    def _generate_readable_report(self) -> str:
        """Generiert einen menschenlesbaren Report"""
        report = []
        report.append(f"NixOS Konfigurationstest - {self.results['timestamp']}\n")
        
        # System Info
        report.append("System Information:")
        for key, value in self.results['system_info'].items():
            report.append(f"  {key}: {value}")
        report.append("")
        
        # Test Statistiken
        report.append("Test Statistiken:")
        report.append(f"  Gesamt Tests: {self.results['total_tests']}")
        report.append(f"  Erfolgreich:  {self.results['passed_tests']}")
        report.append(f"  Fehlgeschlagen: {self.results['failed_tests']}")
        report.append("")
        
        # Fehler Details
        if self.results['failures']:
            report.append("Fehlgeschlagene Tests:")
            for failure in self.results['failures']:
                report.append(f"\nTest: {failure['test']}")
                report.append("-" * 40)
                report.append("Fehler:")
                report.append(failure['error'])
                if failure['config']:
                    report.append("\nVerwendete Konfiguration:")
                    report.append(failure['config'])
                report.append("-" * 40)
        
        return "\n".join(report)