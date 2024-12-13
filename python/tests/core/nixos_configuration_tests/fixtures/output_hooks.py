"""
Output control hooks for pytest.
Uses pytest's native progress reporting with minimal output.
"""

import pytest
from rich.console import Console
from rich.panel import Panel
from rich.progress import Progress, TextColumn, BarColumn, TaskProgressColumn
from rich.style import Style

console = Console()

def pytest_configure(config):
    """
    Configures pytest for minimal but informative output
    """
    # Keep essential reporters
    config.pluginmanager.unregister(name="logging-plugin")
    config.pluginmanager.unregister(name="warnings")
    config.pluginmanager.unregister(name="resultlog")  # Verhindert doppelte Ergebnisausgabe
    
    # Configure output options
    config.option.verbose = 1
    config.option.quiet = False
    config.option.showlocals = False
    config.option.tb = "short"
    config.option.capture = "no"

def pytest_report_header(config):
    """Customize test session header"""
    header = Panel.fit(
        "🚀 NixOS Configuration Tests",
        border_style="blue",
        padding=(1, 2),
        title="Test Session",
        subtitle=f"Strategy: {config.getoption('test_strategy', 'validate-only')}"
    )
    return "\n" + console.render_str(header)

def pytest_runtest_logstart(nodeid, location):
    """Show current test in a clean format"""
    test_name = nodeid.split("::")[-1]
    module_name = nodeid.split("::")[0].split("/")[-1].replace(".py", "")
    console.print(
        f"\n[cyan]Running:[/cyan] [bold blue]{module_name}[/bold blue] → "
        f"[green]{test_name}[/green]"
    )
    return None

def pytest_report_teststatus(report, config):
    """Customize test result indicators"""
    if report.when == "call":
        if report.passed:
            return "passed", "✓", "[bold green]PASS[/bold green]"
        elif report.skipped:
            return "skipped", "○", "[bold yellow]SKIP[/bold yellow]"
        elif report.failed:
            return "failed", "✗", "[bold red]FAIL[/bold red]"
    return None

def pytest_terminal_summary(terminalreporter, exitstatus, config):
    """Clean up the final output"""
    # Nur die pytest Statistik anzeigen, unseren Summary Handler übernimmt den Rest
    stats = terminalreporter.stats
    passed = len(stats.get('passed', []))
    failed = len(stats.get('failed', []))
    skipped = len(stats.get('skipped', []))
    
    if failed:
        console.print("\n[red]Failed Tests:[/red]")
        for report in stats.get('failed', []):
            console.print(f"  [red]✗[/red] {report.nodeid}")
    
    if skipped:
        console.print("\n[yellow]Skipped Tests:[/yellow]")
        for report in stats.get('skipped', []):
            console.print(f"  [yellow]○[/yellow] {report.nodeid}")
    
    return None

def pytest_collection_modifyitems(session, config, items):
    """Show collection info"""
    console.print(f"\n[cyan]Collected[/cyan] [bold]{len(items)}[/bold] tests")

# Remove all other output suppression hooks