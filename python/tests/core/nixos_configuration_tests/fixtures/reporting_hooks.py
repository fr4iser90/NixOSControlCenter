"""
Custom reporting hooks for test execution.
Handles test result reporting and summary generation.
"""

import pytest
from ..handlers.summary_handler import (
    NixConfigErrorHandler,
    SummaryHandler
)

@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """
    Processes test results and updates progress/summary handlers.
    Called after each test completion.
    """
    outcome = yield
    result = outcome.get_result()

    if result.when == "call":
        test_name = item.name
        
        # Update summary handlers
        SummaryHandler.add_result(test_name, result.outcome == "passed")
        if not result.outcome == "passed" and hasattr(result, "longrepr"):
            NixConfigErrorHandler.format_error(str(result.longrepr), test_name)

def pytest_report_teststatus(report, config):
    """
    Customizes test status reporting format.
    Returns empty strings to suppress default output.
    """
    if report.when == "call":
        return report.outcome, "", ""
    return None 