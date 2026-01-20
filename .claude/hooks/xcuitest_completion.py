#!/usr/bin/env python3
"""
XCUITest Completion Hook - ERZWINGT Test-Durchführung UND Bestehen

PFLICHT: Nach UI-Änderungen MÜSSEN XCUITests durchgeführt werden UND bestehen.

Dieser Hook:
1. Prüft ob UI-Dateien geändert wurden
2. Prüft ob XCUITests AUSGEFÜHRT wurden (nicht nur geschrieben)
3. Prüft ob Tests BESTANDEN haben
4. BLOCKT Commit/Validate wenn nicht

KEIN AUSWEG:
- Keine "manuellen Test-Checklisten"
- Keine "du musst das testen"
- Tests MÜSSEN laufen und bestehen

Exit Codes:
- 0: Erlaubt (Tests bestanden oder keine UI-Änderungen)
- 2: BLOCKIERT (Tests nicht durchgeführt oder fehlgeschlagen)
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

# UI-Patterns
UI_PATTERNS = [
    "Tabs/",
    "Tracker/",
    "Views/",
    "/iOS/",
    "Meditationstimer iOS/",
]

# Ausnahmen
EXEMPTIONS = [
    "Services/",
    "Models/",
    "Engine/",
    ".md",
    "Tests/",
    "UITests/",
    "xcstrings",
    "Assets.xcassets",
    "Info.plist",
]

# Test-Konfiguration
SIMULATOR_ID = "EEF5B0DE-6B96-47CE-AA57-2EE024371F00"
PROJECT = "Meditationstimer.xcodeproj"
SCHEME = "Lean Health Timer"
UITEST_TARGET = "LeanHealthTimerUITests"
TEST_TIMEOUT = 600  # 10 Minuten


def get_project_root() -> Path:
    """Find project root."""
    cwd = Path.cwd()
    for parent in [cwd] + list(cwd.parents):
        if (parent / ".git").exists():
            return parent
    return cwd


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


def is_validate_command(tool_input: dict) -> bool:
    """Check if this is a /validate command."""
    command = tool_input.get("command", "")
    prompt = tool_input.get("prompt", "")
    return "/validate" in command or "/validate" in prompt


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


def get_changed_ui_files() -> list[str]:
    """Get list of changed UI files (staged or tracked in workflow)."""
    # Check staged files
    staged = get_staged_files()

    # Also check workflow state for tracked changes
    project_root = get_project_root()
    validation_state = project_root / ".claude" / "validation_state.json"

    tracked_files = []
    if validation_state.exists():
        try:
            with open(validation_state, 'r') as f:
                state = json.load(f)
            tracked_files = state.get("files_changed", [])
        except:
            pass

    all_files = list(set(staged + tracked_files))

    # Filter to UI files
    ui_files = []
    for file_path in all_files:
        # Skip exemptions
        if any(ex in file_path for ex in EXEMPTIONS):
            continue

        # Must be Swift
        if not file_path.endswith(".swift"):
            continue

        # Check UI patterns
        if any(pattern in file_path for pattern in UI_PATTERNS):
            ui_files.append(file_path)

    return ui_files


def get_xcuitest_state() -> dict:
    """Get XCUITest execution state."""
    project_root = get_project_root()
    state_file = project_root / ".claude" / "xcuitest_state.json"

    if state_file.exists():
        try:
            with open(state_file, 'r') as f:
                return json.load(f)
        except:
            pass

    return {}


def save_xcuitest_state(state: dict):
    """Save XCUITest execution state."""
    project_root = get_project_root()
    state_file = project_root / ".claude" / "xcuitest_state.json"

    try:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        with open(state_file, 'w') as f:
            json.dump(state, f, indent=2)
    except:
        pass


def run_xcuitests() -> tuple[bool, str, str]:
    """
    Run XCUITests and return (success, output, summary).
    """
    project_root = get_project_root()

    cmd = [
        "xcodebuild", "test",
        "-project", PROJECT,
        "-scheme", SCHEME,
        "-destination", f"platform=iOS Simulator,id={SIMULATOR_ID}",
        "-only-testing:" + UITEST_TARGET,
        "-resultBundlePath", str(project_root / ".claude" / "xcuitest_results"),
    ]

    print("=" * 70, file=sys.stderr)
    print("🧪 XCUITEST COMPLETION - Führe UI-Tests durch...", file=sys.stderr)
    print("=" * 70, file=sys.stderr)

    try:
        result = subprocess.run(
            cmd,
            cwd=project_root,
            capture_output=True,
            text=True,
            timeout=TEST_TIMEOUT,
        )

        output = result.stdout + result.stderr

        # Parse results
        if "** TEST SUCCEEDED **" in output:
            # Count tests
            test_count = output.count("Test Case")
            passed_count = output.count("passed")

            summary = f"✅ {passed_count} UI-Tests BESTANDEN"
            return True, output, summary

        if "** TEST FAILED **" in output:
            # Extract failures
            failures = []
            for line in output.split("\n"):
                if "failed" in line.lower() and "Test Case" in line:
                    failures.append(line.strip())

            summary = f"❌ UI-Tests FEHLGESCHLAGEN: {len(failures)} Fehler"
            return False, output, summary

        if result.returncode == 0:
            return True, output, "✅ UI-Tests bestanden"

        return False, output, f"❌ UI-Tests fehlgeschlagen (Exit Code: {result.returncode})"

    except subprocess.TimeoutExpired:
        return False, "", f"❌ UI-Tests Timeout nach {TEST_TIMEOUT}s"
    except Exception as e:
        return False, str(e), f"❌ UI-Tests konnten nicht ausgeführt werden: {e}"


def check_xcuitest_completion() -> tuple[bool, str]:
    """
    Check if XCUITests were run and passed.
    Returns (allowed, reason).
    """
    ui_files = get_changed_ui_files()

    if not ui_files:
        return True, "Keine UI-Dateien geändert"

    # UI files changed - check XCUITest state
    state = get_xcuitest_state()

    last_run = state.get("last_run")
    last_success = state.get("success", False)
    last_files = set(state.get("tested_files", []))

    # Check if we have a recent successful run that covers all changed files
    if last_run and last_success:
        try:
            last_run_dt = datetime.fromisoformat(last_run)
            # Must be within last hour
            if datetime.now() - last_run_dt < timedelta(hours=1):
                # Check if all UI files were tested
                current_files = set(ui_files)
                if current_files.issubset(last_files):
                    return True, f"✅ UI-Tests bereits bestanden ({last_run_dt.strftime('%H:%M')})"
        except:
            pass

    # Need to run tests
    print(f"\n📋 UI-Dateien geändert:", file=sys.stderr)
    for f in ui_files[:5]:
        print(f"   • {f}", file=sys.stderr)
    if len(ui_files) > 5:
        print(f"   ... und {len(ui_files) - 5} weitere", file=sys.stderr)
    print(file=sys.stderr)

    success, output, summary = run_xcuitests()

    # Save state
    save_xcuitest_state({
        "last_run": datetime.now().isoformat(),
        "success": success,
        "tested_files": ui_files,
        "summary": summary,
    })

    if success:
        print(file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        print(summary, file=sys.stderr)
        print("=" * 70, file=sys.stderr)
        return True, summary

    # Tests failed - BLOCK
    return False, f"""
╔══════════════════════════════════════════════════════════════════════╗
║  ⛔ BLOCKIERT: UI-TESTS NICHT BESTANDEN!                             ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  {summary:<66} ║
║                                                                      ║
║  ══════════════════════════════════════════════════════════════════  ║
║                                                                      ║
║  Du MUSST die Tests fixen. Kein Ausweg!                              ║
║                                                                      ║
║  ❌ NICHT ERLAUBT:                                                   ║
║     • "Henning, bitte manuell testen"                                ║
║     • "Test-Checkliste für manuelles Testen"                         ║
║     • Commit ohne bestandene Tests                                   ║
║                                                                      ║
║  ✅ WAS DU TUN MUSST:                                                ║
║     1. Fehler analysieren                                            ║
║     2. Test oder Code fixen                                          ║
║     3. Tests erneut ausführen                                        ║
║     4. Wiederholen bis GRÜN                                          ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
"""


def main():
    tool_input = get_tool_input()

    # Only run for git commit or /validate
    if not is_git_commit(tool_input) and not is_validate_command(tool_input):
        sys.exit(0)

    # Check XCUITest completion
    allowed, reason = check_xcuitest_completion()

    if not allowed:
        print(reason, file=sys.stderr)
        sys.exit(2)

    if "✅" in reason:
        print(f"\n{reason}", file=sys.stderr)

    sys.exit(0)


if __name__ == "__main__":
    main()
