"""
Session management hooks for pytest.
Handles test session initialization, timing, and cleanup.
"""

import time
import pytest
from ..handlers.summary_handler import (
    NixConfigErrorHandler,
    SummaryHandler
)

_start_time = time.time()

def pytest_sessionstart(session):
    """
    Initializes test session.
    - Starts timing
    - Clears all handlers
    """
    global _start_time
    _start_time = time.time()
    
    # Reset all handlers
    NixConfigErrorHandler.clear()
    SummaryHandler.clear()

def pytest_sessionfinish(session):
    """
    Finalizes test session.
    - Calculates total execution time
    - Prints summary
    - Prints error report if needed
    - Cleans up handlers
    """
    global _start_time
    
    # Calculate total execution time
    duration = time.time() - _start_time
    SummaryHandler.set_execution_time(duration)
    
    # Print test summary
    print("\n" + SummaryHandler.get_summary())
    
    # Print error summary if errors occurred
    if NixConfigErrorHandler._collected_errors:
        print("\n" + NixConfigErrorHandler.get_summary())

    # Cleanup
    SummaryHandler.clear()
    NixConfigErrorHandler.clear()