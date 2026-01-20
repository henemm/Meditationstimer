#!/usr/bin/env python3
"""
UI Test Enforcement Hook - FORCES UI Tests to PASS

CRITICAL RULE: NO UI changes can be committed without PASSING UI tests.

This hook:
1. Detects UI file changes in staged files
2. RUNS the UI tests automatically
3. BLOCKS commit if tests FAIL
4. Only allows commit if tests PASS

Exit Codes:
- 0: Allowed (tests passed or no UI changes)
- 2: BLOCKED (tests failed or couldn't run)
"""

import json
import os
import subprocess
import sys
from datetime import datetime
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


def get_config() -> dict:
    """Get UI test enforcement configuration."""
    config = load_config()
    enforcement = config.get("ui_test_enforcement", {})

    return {
        "enabled": enforcement.get("enabled", True),
        "simulator_id": enforcement.get("simulator_id", "EEF5B0DE-6B96-47CE-AA57-2EE024371F00"),
        "project": enforcement.get("project", "Meditationstimer.xcodeproj"),
        "scheme": enforcement.get("scheme", "Lean Health Timer"),
        "timeout": enforcement.get("timeout", 600),  # 10 minutes for full UI test suite
        "state_file": enforcement.get("state_file", ".claude/ui_test_state.json"),
        "ui_patterns": [
            "Tabs/",
            "Tracker/",
            "Views/",
            "iOS/",
        ],
        "exemptions": [
            "Services/",
            "Models/",
            ".md",
            "Tests/",  # Unit tests, not UI tests
            "UITests/",  # UI test files themselves
        ],
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
    return "git commit" in command and "--amend" not in command


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


def has_ui_changes(staged_files: list[str], config: dict) -> bool:
    """Check if staged files include UI changes (not exempted)."""
    for file_path in staged_files:
        # Skip exemptions
        if any(ex in file_path for ex in config["exemptions"]):
            continue

        # Check UI patterns
        if any(pattern in file_path for pattern in config["ui_patterns"]):
            return True

        # Swift files in iOS folder are UI
        if file_path.endswith(".swift") and "iOS" in file_path:
            return True

    return False


def prepare_simulator(config: dict) -> bool:
    """Run prepare-simulator.sh script if it exists."""
    project_root = get_project_root()
    script_path = project_root / "scripts" / "prepare-simulator.sh"

    if not script_path.exists():
        return True  # No script, continue anyway

    print("Preparing simulator...", file=sys.stderr)

    try:
        result = subprocess.run(
            [str(script_path), config["simulator_id"]],
            cwd=project_root,
            capture_output=True,
            text=True,
            timeout=60,
        )
        return result.returncode == 0
    except Exception as e:
        print(f"Warning: Could not prepare simulator: {e}", file=sys.stderr)
        return True  # Continue anyway


def run_ui_tests(config: dict) -> tuple[bool, str]:
    """Run UI tests and return (success, output)."""
    project_root = get_project_root()

    # CRITICAL: Prepare simulator first to avoid "Failed to launch" errors
    prepare_simulator(config)

    cmd = [
        "xcodebuild", "test",
        "-project", config["project"],
        "-scheme", config["scheme"],
        "-destination", f"platform=iOS Simulator,id={config['simulator_id']}",
        "-only-testing:LeanHealthTimerUITests",
    ]

    print(f"Running UI tests...", file=sys.stderr)

    try:
        result = subprocess.run(
            cmd,
            cwd=project_root,
            capture_output=True,
            text=True,
            timeout=config["timeout"],
        )

        output = result.stdout + result.stderr

        # Check for success
        if "** TEST SUCCEEDED **" in output:
            return True, output

        if "** TEST FAILED **" in output:
            return False, output

        # Check return code
        if result.returncode == 0:
            return True, output

        return False, output

    except subprocess.TimeoutExpired:
        return False, f"UI tests timed out after {config['timeout']} seconds"
    except Exception as e:
        return False, f"Failed to run UI tests: {e}"


def save_test_state(success: bool, config: dict):
    """Save test state to state file."""
    project_root = get_project_root()
    state_file = project_root / config["state_file"]

    state = {
        "last_run": datetime.now().isoformat(),
        "success": success,
    }

    try:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        with open(state_file, "w") as f:
            json.dump(state, f, indent=2)
    except Exception:
        pass


def main():
    config = get_config()

    if not config["enabled"]:
        sys.exit(0)

    tool_input = get_tool_input()

    if not is_git_commit(tool_input):
        sys.exit(0)

    # Get staged files
    staged_files = get_staged_files()

    if not staged_files:
        sys.exit(0)

    # Check for UI changes
    if not has_ui_changes(staged_files, config):
        # No UI changes - allow commit
        sys.exit(0)

    # UI changes detected - MUST run UI tests
    print("=" * 70, file=sys.stderr)
    print("UI TEST ENFORCEMENT - Running UI Tests", file=sys.stderr)
    print("=" * 70, file=sys.stderr)
    print(file=sys.stderr)
    print("UI files changed. Running UI tests before commit...", file=sys.stderr)
    print(file=sys.stderr)

    success, output = run_ui_tests(config)
    save_test_state(success, config)

    if success:
        print("✅ UI TESTS PASSED - Commit allowed", file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        sys.exit(0)

    # Tests failed - BLOCK
    print("=" * 70, file=sys.stderr)
    print("❌ BLOCKED - UI Tests FAILED", file=sys.stderr)
    print("=" * 70, file=sys.stderr)
    print(file=sys.stderr)
    print("UI tests MUST pass before committing UI changes.", file=sys.stderr)
    print(file=sys.stderr)

    # Extract failure info
    lines = output.split("\n")
    failures = [l for l in lines if "failed" in l.lower() or "FAIL" in l]
    if failures:
        print("Failures:", file=sys.stderr)
        for f in failures[:10]:
            print(f"  {f}", file=sys.stderr)

    print(file=sys.stderr)
    print("Fix the tests, then try again.", file=sys.stderr)
    print("=" * 70, file=sys.stderr)
    sys.exit(2)


if __name__ == "__main__":
    main()
