#!/usr/bin/env python3
"""
Sim-Test Enforcer Hook - ERZWINGT /sim-test Skill für XCUITests

PROBLEM: Claude vergisst ständig, die /sim-test Skill zu verwenden und
führt stattdessen manuell xcodebuild test aus, was zu Simulator-Problemen führt.

LÖSUNG: Dieser Hook BLOCKIERT jeden xcodebuild test mit UITests,
AUSSER die Simulator-Vorbereitung wurde kürzlich durchgeführt.

Exit Codes:
- 0: Erlaubt (Vorbereitung erfolgt oder kein UITest-Befehl)
- 2: BLOCKIERT (Vorbereitung fehlt)
"""

import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path

# Wie alt darf die Simulator-Vorbereitung maximal sein?
MAX_PREP_AGE_MINUTES = 10

# State-Datei die zeigt, dass Vorbereitung durchgeführt wurde
STATE_FILE = ".claude/simulator_ready.json"


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


def is_xcuitest_command(command: str) -> bool:
    """Check if command is an XCUITest execution."""
    command_lower = command.lower()

    # Must be xcodebuild test
    if "xcodebuild" not in command_lower:
        return False
    if "test" not in command_lower:
        return False

    # Must target UI tests
    uitest_indicators = [
        "uitests",
        "leanhealthtimeruitests",
        "ui tests",
        "-only-testing:leanhealthtimeruitests",
    ]

    for indicator in uitest_indicators:
        if indicator in command_lower:
            return True

    return False


def is_simulator_preparation(command: str) -> bool:
    """Check if command is simulator preparation."""
    command_lower = command.lower()

    prep_indicators = [
        "simctl shutdown",
        "simctl boot",
        "bootstatus",
        "coresimulatorservice",
        "prepare-simulator",
    ]

    for indicator in prep_indicators:
        if indicator in command_lower:
            return True

    return False


def check_simulator_ready() -> tuple[bool, str]:
    """
    Check if simulator preparation was done recently.
    Returns (ready, reason).
    """
    project_root = get_project_root()
    state_file = project_root / STATE_FILE

    if not state_file.exists():
        return False, "Keine Simulator-Vorbereitung gefunden"

    try:
        with open(state_file, 'r') as f:
            state = json.load(f)

        last_prep = datetime.fromisoformat(state.get("prepared_at", "2000-01-01"))
        age = datetime.now() - last_prep

        if age > timedelta(minutes=MAX_PREP_AGE_MINUTES):
            return False, f"Vorbereitung zu alt ({int(age.total_seconds() / 60)} Minuten)"

        return True, f"Simulator bereit (vor {int(age.total_seconds() / 60)} Minuten vorbereitet)"

    except Exception as e:
        return False, f"State-Datei nicht lesbar: {e}"


def mark_simulator_ready():
    """Mark simulator as ready (called after preparation)."""
    project_root = get_project_root()
    state_file = project_root / STATE_FILE

    try:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        with open(state_file, 'w') as f:
            json.dump({
                "prepared_at": datetime.now().isoformat(),
                "prepared_by": "sim_test_enforcer"
            }, f, indent=2)
    except Exception as e:
        print(f"⚠️ Konnte State nicht speichern: {e}", file=sys.stderr)


def main():
    # DEBUG: Always log that hook was called
    print("🔍 SIM-TEST-ENFORCER: Hook wurde aufgerufen", file=sys.stderr)

    tool_input = get_tool_input()
    command = tool_input.get("command", "")

    # DEBUG: Log the command
    print(f"🔍 Command: {command[:100]}..." if len(command) > 100 else f"🔍 Command: {command}", file=sys.stderr)

    if not command:
        sys.exit(0)

    # If this is simulator preparation, mark as ready and allow
    if is_simulator_preparation(command):
        mark_simulator_ready()
        sys.exit(0)

    # If this is NOT an XCUITest command, allow
    if not is_xcuitest_command(command):
        sys.exit(0)

    # This IS an XCUITest command - check if preparation was done
    ready, reason = check_simulator_ready()

    if ready:
        print(f"✅ {reason}", file=sys.stderr)
        sys.exit(0)

    # NOT ready - BLOCK!
    print(f"""
╔══════════════════════════════════════════════════════════════════════╗
║  ⛔ BLOCKIERT: SIMULATOR NICHT VORBEREITET!                          ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  Du versuchst XCUITests auszuführen OHNE Vorbereitung.               ║
║                                                                      ║
║  Grund: {reason:<58} ║
║                                                                      ║
║  ══════════════════════════════════════════════════════════════════  ║
║                                                                      ║
║  VERWENDE DIE /sim-test SKILL!                                       ║
║                                                                      ║
║  Die Skill enthält:                                                  ║
║  1. Simulator-Vorbereitung (PFLICHT vor jedem Test-Lauf)             ║
║  2. Korrekte xcodebuild-Flags (-retry-tests-on-failure)              ║
║  3. Fehlerbehandlung für Exit Code 64                                ║
║                                                                      ║
║  ══════════════════════════════════════════════════════════════════  ║
║                                                                      ║
║  Alternativ: Erst Simulator vorbereiten, dann Test wiederholen       ║
║                                                                      ║
║  xcrun simctl shutdown all                                           ║
║  xcrun simctl boot <SIMULATOR_ID>                                    ║
║  xcrun simctl bootstatus <SIMULATOR_ID> -b                           ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
""", file=sys.stderr)

    sys.exit(2)


if __name__ == "__main__":
    main()
