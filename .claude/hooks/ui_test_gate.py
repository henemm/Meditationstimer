#!/usr/bin/env python3
"""
UI Test Gate Hook - FORCE UI Testing for UI Changes

RULE: UI changes REQUIRE corresponding UI tests
- TDD RED: Write failing UI test FIRST
- TDD GREEN: Make test pass, then commit

This hook BLOCKS commits that:
- Change UI files (Views, Tabs, etc.)
- But don't add/modify UI tests

Exit Codes:
- 0: Allowed
- 2: BLOCKED - UI changes without UI tests
"""

import json
import os
import subprocess
import sys
from pathlib import Path

# Try to import config loader
try:
    from config_loader import load_config, get_project_root
except ImportError:
    sys.path.insert(0, str(Path(__file__).parent))
    try:
        from config_loader import load_config, get_project_root
    except ImportError:
        def load_config():
            return {}
        def get_project_root():
            cwd = Path.cwd()
            for parent in [cwd] + list(cwd.parents):
                if (parent / ".git").exists():
                    return parent
            return cwd


def get_ui_test_gate_config() -> dict:
    """Get UI test gate configuration with defaults."""
    config = load_config()
    ui_test_gate = config.get("ui_test_gate", {})

    return {
        "enabled": ui_test_gate.get("enabled", True),
        "ui_patterns": ui_test_gate.get("ui_patterns", [
            "Tabs/",
            "Views/",
            "Tracker/",
            "iOS/",
            ".swift",  # Any Swift file is potentially UI
        ]),
        "ui_test_patterns": ui_test_gate.get("ui_test_patterns", [
            "UITests/",
            "UITests.swift",
        ]),
        "exemptions": ui_test_gate.get("exemptions", [
            "Services/",  # Business logic, not UI
            "Models/",    # Data models
            ".md",        # Documentation
            "Tests/",     # Unit tests
        ]),
    }


def get_tool_input() -> dict:
    """Read tool input from stdin or environment."""
    tool_input_str = os.environ.get("CLAUDE_TOOL_INPUT", "")

    if tool_input_str:
        try:
            return json.loads(tool_input_str)
        except json.JSONDecodeError:
            pass

    try:
        data = json.load(sys.stdin)
        return data.get("tool_input", data)
    except (json.JSONDecodeError, EOFError, Exception):
        return {}


def is_git_commit(tool_input: dict) -> bool:
    """Check if this is a git commit command."""
    command = tool_input.get("command", "")
    return "git commit" in command


def get_staged_files() -> list[str]:
    """Get list of staged files."""
    project_root = get_project_root()

    try:
        result = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            cwd=project_root,
            capture_output=True,
            text=True,
        )

        files = result.stdout.strip().split("\n")
        return [f for f in files if f]
    except Exception:
        return []


def is_ui_file(file_path: str, config: dict) -> bool:
    """Check if file is a UI file (and not exempted)."""
    # Check exemptions first
    for exemption in config["exemptions"]:
        if exemption in file_path:
            return False

    # Check UI patterns
    for pattern in config["ui_patterns"]:
        if pattern in file_path:
            return True

    return False


def is_ui_test_file(file_path: str, config: dict) -> bool:
    """Check if file is a UI test file."""
    for pattern in config["ui_test_patterns"]:
        if pattern in file_path:
            return True
    return False


def main():
    config = get_ui_test_gate_config()

    # Check if enabled
    if not config["enabled"]:
        sys.exit(0)

    tool_input = get_tool_input()

    if not is_git_commit(tool_input):
        sys.exit(0)

    # Get staged files
    staged_files = get_staged_files()

    if not staged_files:
        sys.exit(0)

    # Check for UI file changes
    ui_files_changed = [f for f in staged_files if is_ui_file(f, config)]

    if not ui_files_changed:
        # No UI files changed - allow commit
        sys.exit(0)

    # UI files changed - check if UI test files also changed
    ui_test_files_changed = [f for f in staged_files if is_ui_test_file(f, config)]

    if ui_test_files_changed:
        # UI tests were modified - allow commit
        sys.exit(0)

    # BLOCK: UI changed but no UI tests modified
    print("=" * 70, file=sys.stderr)
    print("BLOCKED - UI Test Gate", file=sys.stderr)
    print("=" * 70, file=sys.stderr)
    print(file=sys.stderr)
    print("UI files were changed, but NO UI tests were modified!", file=sys.stderr)
    print(file=sys.stderr)
    print("TDD RULE:", file=sys.stderr)
    print("1. Write FAILING UI test FIRST (TDD RED)", file=sys.stderr)
    print("2. Implement UI change", file=sys.stderr)
    print("3. Make test PASS (TDD GREEN)", file=sys.stderr)
    print("4. Then commit", file=sys.stderr)
    print(file=sys.stderr)
    print("UI Files Changed:", file=sys.stderr)
    for f in ui_files_changed[:10]:
        print(f"  - {f}", file=sys.stderr)
    print(file=sys.stderr)
    print("You MUST add/modify UI tests in:", file=sys.stderr)
    print("  - LeanHealthTimerUITests/LeanHealthTimerUITests.swift", file=sys.stderr)
    print(file=sys.stderr)
    print("=" * 70, file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
