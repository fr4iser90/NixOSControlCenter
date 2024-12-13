from typing import Dict, Set, List, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from datetime import datetime 
import re
import json
import logging
from rich.logging import RichHandler
import os

logger = logging.getLogger(__name__)

logging.basicConfig(
    level=logging.DEBUG,
    format="%(message)s",
    datefmt="[%X]",
    handlers=[RichHandler(rich_tracebacks=True)]
)
class NixOSErrorType(Enum):
    SYNTAX_ERROR = "syntax_error"
    TYPE_ERROR = "type_error"
    UNDEFINED_REFERENCE = "undefined_reference"
    OPTION_ERROR = "option_error"
    MODULE_ERROR = "module_error"
    EVALUATION_ERROR = "evaluation_error"
    BUILD_ERROR = "build_error"
    DEPENDENCY_ERROR = "dependency_error"
    CONFIGURATION_ERROR = "configuration_error"
    PERMISSION_ERROR = "permission_error"
    UNKNOWN = "unknown"

@dataclass(frozen=False)
class NixOSError:
    error_type: NixOSErrorType
    message: str
    location: Optional[str] = None
    file_path: Optional[str] = None
    line_number: Optional[int] = None
    column: Optional[int] = None
    context: Optional[str] = None
    suggestion: Optional[str] = None
    stack_trace: Optional[List[str]] = None
    related_errors: Optional[List['NixOSError']] = None
    severity: str = "error"

class NixOSErrorParser:
    """Parser für verschiedene NixOS Fehlertypen"""
    
    _ERROR_PATTERNS = {
        # Syntax Fehler
        r"error: syntax error, unexpected (.+)": NixOSErrorType.SYNTAX_ERROR,
        r"error: syntax error, (.+)": NixOSErrorType.SYNTAX_ERROR,
        
        # Typ Fehler
        r"error: value is (.+) while a (.+) was expected": NixOSErrorType.TYPE_ERROR,
        r"error: type (.+) does not support (.+)": NixOSErrorType.TYPE_ERROR,
        
        # Referenz Fehler
        r"error: undefined variable '(.+)'": NixOSErrorType.UNDEFINED_REFERENCE,
        r"error: attribute '(.+)' missing": NixOSErrorType.UNDEFINED_REFERENCE,
        
        # Option Fehler
        r"The option `(.+)' does not exist": NixOSErrorType.OPTION_ERROR,
        r"The option `(.+)' is used but not defined": NixOSErrorType.OPTION_ERROR,
        
        # Modul Fehler
        r"The module `(.+)' does not exist": NixOSErrorType.MODULE_ERROR,
        r"Failed to load module '(.+)'": NixOSErrorType.MODULE_ERROR,
        
        # Build Fehler
        r"builder for '(.+)' failed": NixOSErrorType.BUILD_ERROR,
        r"cannot build derivation '(.+)'": NixOSErrorType.BUILD_ERROR,
        
        # Abhängigkeits Fehler
        r"cycle detected in (.+)": NixOSErrorType.DEPENDENCY_ERROR,
        r"dependency '(.+)' not found": NixOSErrorType.DEPENDENCY_ERROR
    }

    @classmethod
    def extract_stack_trace(cls, error_text: str) -> List[str]:
        """Extrahiert den Stack Trace aus der Fehlermeldung"""
        stack_lines = []
        in_stack = False
        for line in error_text.split('\n'):
            if line.strip().startswith("at "):
                in_stack = True
                stack_lines.append(line.strip())
            elif in_stack and not line.strip():
                break
        return stack_lines

    @classmethod
    def parse_error(cls, error_text: str) -> NixOSError:
        """Parst eine NixOS Fehlermeldung"""
        file_path, line_number, column = cls.parse_location(error_text)
        stack_trace = cls.extract_stack_trace(error_text)
        
        error_type = NixOSErrorType.UNKNOWN
        message = error_text
        context = None
        
        # Fehlertyp und Details bestimmen
        for pattern, err_type in cls._ERROR_PATTERNS.items():
            match = re.search(pattern, error_text)
            if match:
                error_type = err_type
                message = match.group(0)
                break

        # Kontext extrahieren
        context = cls.extract_context(error_text, line_number if line_number else 0)
        
        return NixOSError(
            error_type=error_type,
            message=message,
            location=f"{file_path}:{line_number}" if file_path and line_number else None,
            file_path=file_path,
            line_number=line_number,
            column=column,
            context=context,
            suggestion=cls.generate_suggestion(error_type, message),
            stack_trace=stack_trace,
            severity=cls.determine_severity(error_type)
        )

    @staticmethod
    def determine_severity(error_type: NixOSErrorType) -> str:
        """Bestimmt den Schweregrad des Fehlers"""
        critical_errors = {NixOSErrorType.BUILD_ERROR, NixOSErrorType.DEPENDENCY_ERROR}
        if error_type in critical_errors:
            return "critical"
        return "error"

    @staticmethod
    def extract_context(error_text: str, line_number: int, context_lines: int = 3) -> Optional[str]:
        """Extrahiert den Kontext um die Fehlerposition"""
        lines = error_text.split('\n')
        start = max(0, line_number - context_lines - 1)
        end = min(len(lines), line_number + context_lines)
        return '\n'.join(lines[start:end]) if start < end else None

class NixOSErrorHandler:
    """Handler für NixOS Konfigurationsfehler mit verbesserter Lesbarkeit"""
    
    def __init__(self):
        self.errors: List[NixOSError] = []
        self.parser = NixOSErrorParser()

    def add_error(self, error_text: Any) -> None:
        """Analysiert und fügt einen neuen Fehler hinzu"""
        try:
            # Speichere den originalen Build-Log
            self._last_build_log = str(error_text)

            # Konvertiere error_text zu String, falls es ein NixOSError ist
            if isinstance(error_text, NixOSError):
                error_text = error_text.message
            elif not isinstance(error_text, str):
                error_text = str(error_text)

            logger.debug(f"Processing error text: {error_text[:200]}...")  # Log first 200 chars
            
            # Hauptfehler extrahieren
            main_error = self._extract_main_error(error_text)
            if main_error:
                self.errors.append(main_error)
                logger.info(f"Successfully added error of type: {main_error.error_type}")
                logger.debug(f"Error details: {main_error}")
            else:
                # Fallback für unbekannte Fehler
                fallback_error = NixOSError(
                    error_type=NixOSErrorType.UNKNOWN,
                    message=error_text
                )
                self.errors.append(fallback_error)
                logger.warning(f"Added fallback error: {fallback_error}")
                
        except Exception as e:
            logger.error(f"Failed to process error: {str(e)}", exc_info=True)
            # Füge trotzdem einen generischen Fehler hinzu
            self.errors.append(NixOSError(
                error_type=NixOSErrorType.UNKNOWN,
                message=str(error_text)
            ))

    def _extract_main_error(self, error_text: str) -> Optional[NixOSError]:
        """Extrahiert den Hauptfehler aus der Fehlermeldung"""
        
        # Bekannte Fehlermuster
        patterns = [
            # Null-Wert Fehler
            (r"error: cannot coerce null to a string: null",
             lambda m: NixOSError(
                 error_type=NixOSErrorType.TYPE_ERROR,
                 message="Ein Wert ist null, wo ein String erwartet wird",
                 suggestion="Stelle sicher, dass der Wert definiert ist"
             )),
            
            # Attribut Fehler
            (r"error: attribute '(.+)' missing",
             lambda m: NixOSError(
                 error_type=NixOSErrorType.UNDEFINED_REFERENCE, 
                 message=f"Das Attribut '{m.group(1)}' fehlt",
                 suggestion=f"Definiere das Attribut '{m.group(1)}'"
             )),
            
            # Typ Fehler
            (r"error: value is (.+) while a (.+) was expected",
             lambda m: NixOSError(
                 error_type=NixOSErrorType.TYPE_ERROR,
                 message=f"Falscher Typ: {m.group(1)} statt {m.group(2)}",
                 suggestion="Überprüfe den Typ des Wertes"
             ))
        ]

        # Datei und Zeile extrahieren
        location_match = re.search(r"at (.+):(\d+):", error_text)
        file_path = location_match.group(1) if location_match else None
        line_num = int(location_match.group(2)) if location_match else None

        # Nach bekannten Fehlermustern suchen
        for pattern, error_factory in patterns:
            match = re.search(pattern, error_text)
            if match:
                error = error_factory(match)
                error.file_path = file_path
                error.line_number = line_num
                return error

        # Generischer Fehler als Fallback
        return NixOSError(
            error_type=NixOSErrorType.UNKNOWN,
            message=self._simplify_error_message(error_text),
            file_path=file_path,
            line_number=line_num
        )

    def _simplify_error_message(self, error_text: str) -> str:
        """Vereinfacht die Fehlermeldung für bessere Lesbarkeit"""
        # Erste relevante Fehlerzeile finden
        lines = error_text.split('\n')
        for line in lines:
            if "error:" in line:
                # Unnötige Details entfernen
                message = re.sub(r'at .*?:', '', line)
                message = re.sub(r'\s+', ' ', message).strip()
                return message
        return error_text.split('\n')[0]

    def get_summary(self, test_name: Optional[str] = None) -> str:
        """Erstellt eine lesbare Zusammenfassung der Fehler"""
        # Debug print
        print("\nDEBUG get_summary:")
        print(f"test_name: {test_name}")
        print(f"self._test_name: {getattr(self, '_test_name', 'NOT SET')}")
        print(f"self._python_config: {getattr(self, '_python_config', 'NOT SET')}")
        print(f"self._nix_config: {getattr(self, '_nix_config', 'NOT SET')}")
        
        # Header mit Konfigurationen
        summary = [
            "=== NixOS Configuration Error Log ===",
            f"Test: {test_name or self._test_name}",
            f"Time: {datetime.now().isoformat()}",
            "\n=== Python Configuration ===",
            str(self._python_config) if hasattr(self, '_python_config') else "No Python configuration available",
            "\n=== Generated NixOS Configuration ===", 
            self._nix_config if hasattr(self, '_nix_config') else "No Nix configuration available",
            "\n=== Environment Details ===",
            self._get_environment_details(),
            "\n=== Error Summary ==="
        ]

        if not self.errors:
            summary.append("Keine NixOS Konfigurationsfehler gefunden")
        else:
            for i, error in enumerate(self.errors, 1):
                summary.extend([
                    f"\nFehler {i}:",
                    f"• Was: {error.message}"
                ])
                
                if error.file_path:
                    summary.append(f"• Wo: {error.file_path}" + 
                                (f" (Zeile {error.line_number})" if error.line_number else ""))
                    
                if error.suggestion:
                    summary.append(f"• Lösung: {error.suggestion}")

        summary_text = "\n".join(summary)
        
        # Speichere Log-Datei wenn ein Test-Name vorhanden ist
        if test_name:
            self._save_error_log(test_name, summary_text)
            
        return summary_text

    def _save_error_log(self, test_name: str, summary_text: str) -> None:
        """Speichert den Error-Log in eine Datei"""
        try:
            # Erstelle Log-Verzeichnis im Projekt-Root
            project_root = Path(__file__).parent.parent.parent.parent.parent
            log_dir = project_root / "logs" / "nixos_error_logs"
            log_dir.mkdir(exist_ok=True, parents=True)
            
            # Erstelle und teste die Log-Datei
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            log_file = log_dir / f"nixos_errors_{test_name}_{timestamp}.log"
            
            # Bereite Log-Inhalt vor
            full_log = [
                summary_text,
                "\n=== Raw Errors ==="
            ]
            
            # Schreibe in die Datei
            with log_file.open('w') as f:
                f.write('\n'.join(full_log))
                if self.errors:
                    for error in self.errors:
                        error_details = {
                            'type': error.error_type.value,
                            'message': error.message,
                            'location': error.location,
                            'file_path': str(error.file_path) if error.file_path else None,
                            'line_number': error.line_number,
                            'column': error.column,
                            'context': error.context,
                            'suggestion': error.suggestion,
                            'stack_trace': error.stack_trace,
                            'severity': error.severity
                        }
                        f.write('\n' + json.dumps(error_details, indent=2))
                
                # Füge den Build-Log hinzu
                f.write("\n\n=== NixOS Build Log ===\n")
                if hasattr(self, '_last_build_log') and self._last_build_log:
                    formatted_log = self._format_build_log(self._last_build_log)
                    f.write(formatted_log)
                else:
                    f.write("No build log available")
            
            # Setze Berechtigungen
            log_file.chmod(0o644)
            self._current_log_file = log_file
            logger.info(f"Successfully wrote error log to: {log_file}")
            
        except Exception as e:
            logger.error(f"Failed to save error log: {e}", exc_info=True)

    def _get_environment_details(self) -> str:
        """Gibt die Details der verwendeten Umgebung zurück"""
        # Beispiel: Extrahiere Details aus dem Build-Log
        env_details = []
        if hasattr(self, '_last_build_log') and self._last_build_log:
            for line in self._last_build_log.split('\n'):
                if line.startswith('• Added input'):
                    env_details.append(line)
        return '\n'.join(env_details)

    def _format_build_log(self, log_text: str) -> str:
        """Formatiert den Build-Log für bessere Lesbarkeit"""
        # Entferne die NixOSError Wrapper-Formatierung
        if "NixOSError(" in log_text:
            try:
                # Extrahiere den eigentlichen Fehlertext
                message_start = log_text.find("message='") + 9
                message_end = log_text.find("', location=")
                log_text = log_text[message_start:message_end]
                
                # Ersetze Escape-Sequenzen
                log_text = log_text.replace('\\n', '\n')
                log_text = log_text.replace("\\'", "'")
            except Exception:
                pass  # Falls die Extraktion fehlschlägt, behalte den Original-Text

        # Formatiere den Stack Trace
        formatted_lines = []
        current_indent = 0
        for line in log_text.split('\n'):
            # Entferne übermäßige Leerzeichen
            line = line.strip()
            
            # Überspringen leerer Zeilen
            if not line:
                formatted_lines.append('')
                continue

            # Setze Einrückung basierend auf Kontext
            if line.startswith('… while'):
                current_indent = 2
            elif line.startswith('error:'):
                current_indent = 0
            elif any(line.startswith(x) for x in ['at ', '-', 'Use ']):
                current_indent = 4
            
            # Füge formatierte Zeile hinzu
            formatted_lines.append(' ' * current_indent + line)

        # Füge Trennlinien für bessere Lesbarkeit hinzu
        formatted_text = '\n'.join(formatted_lines)
        
        # Füge Rahmen für wichtige Fehlermeldungen hinzu
        formatted_text = re.sub(
            r'(error: .*?)(\n|$)', 
            r'╭─────────────────────────────────╮\n│ \1 │\n╰─────────────────────────────────╯\n', 
            formatted_text
        )

        return formatted_text

    def _format_test_config(self, config: Dict) -> str:
        """Formatiert die Testkonfiguration für bessere Lesbarkeit"""
        if not config:
            return "No configuration provided"
        
        formatted = ["Test Configuration:"]
        
        # Hauptkonfiguration
        main_config = {k: v for k, v in config.items() if k != 'overrides'}
        formatted.append("\nMain Settings:")
        for key, value in main_config.items():
            formatted.append(f"  {key}: {value}")
        
        # Overrides separat
        if 'overrides' in config:
            formatted.append("\nOverrides:")
            for key, value in config['overrides'].items():
                formatted.append(f"  {key}: {value}")
        
        return '\n'.join(formatted)

    def get_current_log_file(self) -> Optional[Path]:
        """Gibt den Pfad der aktuellen Log-Datei zurück"""
        if not hasattr(self, '_current_log_file'):
            return None
        return self._current_log_file

    def store_configs(self, test_name: str, python_config: Dict, nix_config: str) -> None:
        """Speichert beide Konfigurationen für spätere Verwendung"""
        self._test_name = test_name
        self._python_config = python_config
        self._nix_config = nix_config

def export_errors(self, test_name: str, export_dir: Path) -> None:
    """Exportiert die Fehler in eine JSON-Datei"""
    try:
        # Erstelle Export-Verzeichnis falls es nicht existiert
        export_dir.mkdir(parents=True, exist_ok=True)
        
        # Erstelle Dateinamen
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        export_file = export_dir / f"{test_name}_{timestamp}_errors.json"
        
        # Bereite Export-Daten vor
        export_data = {
            "test_name": test_name,
            "timestamp": timestamp,
            "errors": [
                {
                    "type": error.error_type.value,
                    "message": error.message,
                    "location": error.location,
                    "file_path": str(error.file_path) if error.file_path else None,
                    "line_number": error.line_number,
                    "suggestion": error.suggestion,
                    "severity": error.severity
                }
                for error in self.errors
            ],
            "build_log": self._last_build_log if hasattr(self, '_last_build_log') else None,
            "python_config": self._python_config if hasattr(self, '_python_config') else None,
            "nix_config": self._nix_config if hasattr(self, '_nix_config') else None
        }
        
        # Schreibe in Datei
        with export_file.open('w') as f:
            json.dump(export_data, f, indent=2)
            
        logger.info(f"Successfully exported errors to: {export_file}")
        
    except Exception as e:
        logger.error(f"Failed to export errors: {e}", exc_info=True)