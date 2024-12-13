# src/core/utils/summary_handler.py
from typing import Dict, Set, List
from dataclasses import dataclass
from collections import defaultdict

@dataclass(frozen=True)
class NixError:
    test_name: str
    error_type: str
    location: str
    details: str
    original_message: str
    
    def __hash__(self):
        return hash((self.test_name, self.error_type, self.location, self.details))

class NixConfigErrorHandler:
    """Handler für NixOS Konfigurationsfehler"""
    _collected_errors: Set[NixError] = set()
    _test_errors: Dict[str, Set[NixError]] = defaultdict(set)
    
    @classmethod
    def collect_error(cls, error: NixError) -> None:
        cls._collected_errors.add(error)
        cls._test_errors[error.test_name].add(error)

    @classmethod
    def format_error(cls, error_text: str, test_name: str) -> str:
        error = cls.parse_nix_error(error_text, test_name)
        cls.collect_error(error)
        return error.original_message

    @staticmethod
    def parse_nix_error(error_text: str, test_name: str) -> NixError:
        error_type = "Evaluation Error"
        location = ""
        details = "Unknown error"
        
        for line in error_text.split('\n'):
            if "at" in line and ":" in line:
                location = line.split("at")[-1].strip()
            elif "error:" in line:
                details = line.strip()
        
        return NixError(
            test_name=test_name,
            error_type=error_type,
            location=location,
            details=details,
            original_message=error_text
        )

    @classmethod
    def get_summary(cls) -> str:
        if not cls._collected_errors:
            return "No NixOS configuration errors detected"
            
        summary = [
            "================================================================================",
            "📋 NixOS Configuration Errors",
            "================================================================================",
            "",
        ]
        
        for test_name, errors in cls._test_errors.items():
            for error in errors:
                summary.extend([
                    f"Test: {test_name}",
                    f"Type: {error.error_type}",
                    f"Location: {error.location}",
                    f"Details: {error.details}",
                    "",
                    "Original Error:",
                    error.original_message,
                    "--------------------------------------------------------------------------------",
                    ""
                ])
        
        return "\n".join(summary)

    @classmethod
    def clear(cls) -> None:
        cls._collected_errors.clear()
        cls._test_errors.clear()

class SummaryHandler:
    """Handler für die Testzusammenfassung"""
    _passed_tests: List[str] = []
    _failed_tests: List[str] = []
    _execution_time: float = 0.0

    @classmethod
    def add_result(cls, test_name: str, passed: bool) -> None:
        if passed:
            cls._passed_tests.append(test_name)
        else:
            cls._failed_tests.append(test_name)

    @classmethod
    def set_execution_time(cls, time: float) -> None:
        cls._execution_time = time

    @classmethod
    def get_summary(cls) -> str:
        summary = [
            "================================================================================",
            "📊 Test Results Summary",
            "================================================================================",
            "",
            "📌 Test Results:",
        ]

        # Gruppiere Tests nach Kategorien
        for test in cls._passed_tests:
            summary.append(f"  ✅ {test}")
        for test in cls._failed_tests:
            summary.append(f"  ❌ {test}")

        summary.extend([
            "",
            "--------------------------------------------------------------------------------",
            "📈 Statistics:",
            f"  ✅ Passed:  {len(cls._passed_tests)}",
            f"  ❌ Failed:  {len(cls._failed_tests)}",
            f"  ⏱️  Time:    {cls._execution_time:.2f}s",
            "================================================================================",
            ""
        ])

        return "\n".join(summary)

    @classmethod
    def clear(cls) -> None:
        cls._passed_tests.clear()
        cls._failed_tests.clear()
        cls._execution_time = 0.0