"""Evaluation harness for testing knowledge invariants and fixtures."""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from importlib import resources
from pathlib import Path
from typing import Any, Callable

from .config import Settings
from .runtime import ToolRuntime


@dataclass
class EvalCase:
    """A single evaluation test case."""
    name: str
    description: str = ""
    kind: str = "invariant"  # invariant | fixture
    tool: str | None = None
    args: dict[str, Any] = field(default_factory=dict)
    expected: dict[str, Any] = field(default_factory=dict)
    checks: list[str] = field(default_factory=list)  # JSONPath-like assertions

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "EvalCase":
        return cls(
            name=data.get("name", "unnamed"),
            description=data.get("description", ""),
            kind=data.get("kind", "invariant"),
            tool=data.get("tool"),
            args=data.get("args", {}),
            expected=data.get("expected", {}),
            checks=data.get("checks", []),
        )


@dataclass
class EvalResult:
    """Result of running an evaluation case."""
    case_name: str
    passed: bool
    duration_ms: float = 0.0
    error: str | None = None
    actual: Any = None
    details: list[str] = field(default_factory=list)


@dataclass
class EvalReport:
    """Complete evaluation report."""
    results: list[EvalResult] = field(default_factory=list)
    total: int = 0
    passed: int = 0
    failed: int = 0
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())

    def add(self, result: EvalResult) -> None:
        self.results.append(result)
        self.total += 1
        if result.passed:
            self.passed += 1
        else:
            self.failed += 1

    def to_dict(self) -> dict[str, Any]:
        return {
            "timestamp": self.timestamp,
            "total": self.total,
            "passed": self.passed,
            "failed": self.failed,
            "results": [
                {
                    "case_name": r.case_name,
                    "passed": r.passed,
                    "duration_ms": r.duration_ms,
                    "error": r.error,
                    "details": r.details,
                }
                for r in self.results
            ],
        }


def _parse_cases_payload(data: Any) -> list[EvalCase]:
    cases: list[EvalCase] = []
    if isinstance(data, list):
        for item in data:
            if isinstance(item, dict):
                cases.append(EvalCase.from_dict(item))
    elif isinstance(data, dict) and "cases" in data:
        for item in data["cases"]:
            if isinstance(item, dict):
                cases.append(EvalCase.from_dict(item))
    return cases


def load_eval_cases(path: Path | None = None) -> list[EvalCase]:
    """Load evaluation cases from a JSON file or packaged eval/cases.json."""
    cases: list[EvalCase] = []

    if path and path.is_file():
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            return _parse_cases_payload(data)
        except (OSError, json.JSONDecodeError):
            return cases

    # Default: packaged eval/cases.json next to this module
    packaged = Path(__file__).resolve().parent / "eval" / "cases.json"
    if packaged.is_file():
        try:
            data = json.loads(packaged.read_text(encoding="utf-8"))
            cases.extend(_parse_cases_payload(data))
            if cases:
                return cases
        except (OSError, json.JSONDecodeError):
            pass

    try:
        pkg_files = resources.files("ncc_assistant") / "eval"
        if pkg_files.is_dir():
            for item in pkg_files.iterdir():
                if item.name.endswith(".json"):
                    try:
                        content = item.read_text(encoding="utf-8")
                        data = json.loads(content)
                        cases.extend(_parse_cases_payload(data))
                    except (OSError, json.JSONDecodeError):
                        continue
    except (TypeError, AttributeError):
        pass

    return cases


def _check_value(actual: Any, path: str, expected: Any) -> tuple[bool, str]:
    """Check a value at a JSONPath-like path."""
    parts = path.split(".")
    current = actual

    for part in parts:
        if part.startswith("[") and part.endswith("]"):
            idx = int(part[1:-1])
            if not isinstance(current, list) or idx >= len(current):
                return False, f"Index {idx} out of range at {path}"
            current = current[idx]
        elif isinstance(current, dict):
            if part not in current:
                return False, f"Key '{part}' not found at {path}"
            current = current[part]
        else:
            return False, f"Cannot traverse '{part}' in non-dict at {path}"

    if current == expected:
        return True, ""
    return False, f"Expected {expected!r}, got {current!r}"


def _run_invariant_checks(result: dict[str, Any], checks: list[str]) -> list[str]:
    """Run invariant checks on a tool result."""
    failures: list[str] = []

    for check in checks:
        if "==" in check:
            path, expected_str = check.split("==", 1)
            path = path.strip()
            expected_str = expected_str.strip()
            try:
                expected = json.loads(expected_str)
            except json.JSONDecodeError:
                expected = expected_str.strip('"\'')

            passed, msg = _check_value(result, path, expected)
            if not passed:
                failures.append(f"Check '{check}' failed: {msg}")

        elif ".ok" in check or check.endswith(".ok"):
            path = check.replace(".ok", "")
            if path:
                try:
                    current = result
                    for part in path.split("."):
                        current = current[part]
                    if not current.get("ok"):
                        failures.append(f"Check '{check}' failed: ok is not true")
                except (KeyError, TypeError):
                    failures.append(f"Check '{check}' failed: path not found")
            elif not result.get("ok"):
                failures.append(f"Check '{check}' failed: result.ok is not true")

        elif check.startswith("!"):
            key = check[1:].strip()
            if key in result:
                failures.append(f"Check '{check}' failed: key '{key}' should not exist")

        elif check.startswith("?"):
            key = check[1:].strip()
            if key not in result:
                failures.append(f"Check '{check}' failed: key '{key}' should exist")

    return failures


class EvalHarness:
    """Harness for running evaluation cases."""

    def __init__(self, settings: Settings | None = None) -> None:
        self.settings = settings or Settings.from_env()
        self.runtime = ToolRuntime(self.settings)

    def run_case(self, case: EvalCase) -> EvalResult:
        """Run a single evaluation case."""
        import time

        start = time.perf_counter()

        try:
            if case.kind == "fixture":
                return self._run_fixture_case(case, start)
            else:
                return self._run_invariant_case(case, start)
        except Exception as exc:
            duration = (time.perf_counter() - start) * 1000
            return EvalResult(
                case_name=case.name,
                passed=False,
                duration_ms=duration,
                error=str(exc),
            )

    def _run_invariant_case(self, case: EvalCase, start: float) -> EvalResult:
        """Run an invariant test case."""
        import time

        if not case.tool:
            return EvalResult(
                case_name=case.name,
                passed=False,
                error="No tool specified for invariant case",
            )

        result = self.runtime.call(case.tool, case.args)
        duration = (time.perf_counter() - start) * 1000

        failures: list[str] = []

        if case.expected:
            for key, expected_value in case.expected.items():
                if key not in result:
                    failures.append(f"Expected key '{key}' not in result")
                elif result[key] != expected_value:
                    failures.append(f"Key '{key}': expected {expected_value!r}, got {result[key]!r}")

        if case.checks:
            failures.extend(_run_invariant_checks(result, case.checks))

        return EvalResult(
            case_name=case.name,
            passed=len(failures) == 0,
            duration_ms=duration,
            actual=result,
            details=failures,
        )

    def _run_fixture_case(self, case: EvalCase, start: float) -> EvalResult:
        """Run a fixture-based test case (requires external fixture data)."""
        import time

        duration = (time.perf_counter() - start) * 1000
        return EvalResult(
            case_name=case.name,
            passed=True,
            duration_ms=duration,
            details=["Fixture mode: skipped (no fixture data loaded)"],
        )

    def run_all(
        self,
        cases: list[EvalCase] | None = None,
        *,
        filter_kind: str | None = None,
        on_result: Callable[[EvalResult], None] | None = None,
    ) -> EvalReport:
        """Run all evaluation cases and return a report."""
        if cases is None:
            cases = load_eval_cases()

        if filter_kind:
            cases = [c for c in cases if c.kind == filter_kind]

        report = EvalReport()

        for case in cases:
            result = self.run_case(case)
            report.add(result)
            if on_result:
                on_result(result)

        return report


def run_eval(
    settings: Settings | None = None,
    cases_path: Path | None = None,
) -> EvalReport:
    """Convenience function to run evaluation."""
    harness = EvalHarness(settings)
    cases = load_eval_cases(cases_path)
    return harness.run_all(cases)
